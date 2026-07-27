resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = "groceryssh"
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_s3.name

  lifecycle {
    ignore_changes = [ami]
  }

  # Re-run the bootstrap (recreate the instance) whenever the script changes.
  user_data_replace_on_change = true

  # Bootstrap script — runs once on first boot (output: /var/log/cloud-init-output.log).
  # Terraform substitutes every ${...} below BEFORE the instance sees the script,
  # so the real DB host/creds are baked in. $(...) is left for the shell to run.
  user_data = <<-EOF
#!/bin/bash
set -e

# 1. Install tooling and enable Docker on every boot
dnf install -y git docker openssl
systemctl enable --now docker
usermod -aG docker ec2-user

# 2. Fetch the application source
cd /home/ec2-user
git clone https://github.com/cluebbers/AWS_grocery.git
cd AWS_grocery/backend

# 3. Build the image
docker build -t grocerymate .

# 4. Run it, injecting config at runtime with -e, restarting on failure and on reboot.
#    JWT secret is generated on the box; DB values come from Terraform.
docker run -d --restart unless-stopped --network host \
  -e JWT_SECRET_KEY=$(openssl rand -hex 32) \
  -e USE_S3_STORAGE=true \
  -e S3_BUCKET_NAME=${aws_s3_bucket.avatars.bucket} \
  -e S3_REGION=${var.aws_region} \
  -e POSTGRES_USER=${var.db_username} \
  -e POSTGRES_PASSWORD=${var.db_password} \
  -e POSTGRES_DB=${var.db_name} \
  -e POSTGRES_HOST=${aws_db_instance.postgres.address} \
  -e POSTGRES_URI=postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.address}:5432/${var.db_name} \
  grocerymate
EOF

  tags = {
    Name = "grocerymate-app"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}
