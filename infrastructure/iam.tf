resource "aws_iam_role" "ec2_s3" {
  name = "grocerymate-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "s3_access" {
  name = "grocerymate-s3-access"
  role = aws_iam_role.ec2_s3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
      ]
      Resource = [
        aws_s3_bucket.avatars.arn,
        "${aws_s3_bucket.avatars.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_s3" {
  name = "grocerymate-ec2-profile"
  role = aws_iam_role.ec2_s3.name
}
