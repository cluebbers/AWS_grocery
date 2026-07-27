# Infrastructure (Terraform)

Provisions the GroceryMate app on AWS: **EC2 + Security Groups + RDS (PostgreSQL)** in the default VPC (`eu-central-1`). The EC2 `user_data` installs Docker, clones the repo, builds the image, and runs the app against RDS with config injected at runtime.

## Deploy

Set `db_password` and `my_ip` (your IP as `x.x.x.x/32`) in `terraform.tfvars`, then:

```bash
terraform init
terraform apply
```

Outputs the EC2 public IP (`app_ip`) and the RDS endpoint (`rds_endpoint`).

## ⚠️ Required one-time step: seed the database

The app **skips migrations when it detects RDS** (see `backend/manage.py`), so a fresh RDS has **no tables** and registration fails until the schema is loaded. This is **not** automated in Terraform — run it once, from the EC2 (RDS is private, so only the EC2 can reach it):

```bash
ssh -i <your-key>.pem ec2-user@$(terraform output -raw app_ip)

sudo dnf install -y postgresql15
RDS_HOST=$(docker exec $(docker ps -q) printenv POSTGRES_HOST)
cd /home/ec2-user/AWS_grocery/backend
PGPASSWORD=<db_password> psql -h "$RDS_HOST" -U grocery_user -d grocerymate_db \
  -f app/sqlite_dump_clean.sql
```

The data lives in RDS and survives EC2 rebuilds, so this is only needed **once** per database.

## Teardown

```bash
terraform destroy
```

`skip_final_snapshot = true` lets the RDS instance delete without prompting for a snapshot.
