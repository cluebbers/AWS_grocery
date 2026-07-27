# ============================================================
# EC2 health-check alerting: EventBridge → Lambda → SNS (email)
# ============================================================

# --- SNS topic + email subscription -------------------------
resource "aws_sns_topic" "health_alerts" {
  name         = "grocerymate-ec2-health-alerts"
  display_name = "GroceryMate"
}

# Email endpoint. AWS sends a confirmation email — you must click the link
# before any alerts are delivered (subscription stays "pending" until then).
resource "aws_sns_topic_subscription" "health_email" {
  topic_arn = aws_sns_topic.health_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- IAM role for the Lambda --------------------------------
resource "aws_iam_role" "lambda_healthcheck" {
  name = "grocerymate-lambda-healthcheck-role"

  # Trust policy: the Lambda service may assume this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Basic execution = permission to write logs to CloudWatch (AWS-managed).
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_healthcheck.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Read-only EC2 access so the function can describe instances (AWS-managed).
resource "aws_iam_role_policy_attachment" "lambda_ec2_readonly" {
  role       = aws_iam_role.lambda_healthcheck.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

# Publish only to THIS topic (scoped inline policy — least privilege,
resource "aws_iam_role_policy" "lambda_sns_publish" {
  name = "grocerymate-lambda-sns-publish"
  role = aws_iam_role.lambda_healthcheck.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = aws_sns_topic.health_alerts.arn
    }]
  })
}

# --- Package the function code into a zip -------------------
data "archive_file" "healthcheck" {
  type        = "zip"
  source_file = "${path.module}/lambda/healthcheck.py"
  output_path = "${path.module}/lambda/healthcheck.zip"
}

# --- The Lambda function ------------------------------------
resource "aws_lambda_function" "healthcheck" {
  function_name = "grocerymate-ec2-healthcheck"
  role          = aws_iam_role.lambda_healthcheck.arn
  handler       = "healthcheck.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30

  filename         = data.archive_file.healthcheck.output_path
  source_code_hash = data.archive_file.healthcheck.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.health_alerts.arn
    }
  }
}

# --- EventBridge schedule (runs the function every minute) --
resource "aws_cloudwatch_event_rule" "healthcheck_schedule" {
  name                = "grocerymate-ec2-healthcheck-schedule"
  description         = "Trigger the EC2 health check on a schedule"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "healthcheck" {
  rule      = aws_cloudwatch_event_rule.healthcheck_schedule.name
  target_id = "grocerymate-ec2-healthcheck"
  arn       = aws_lambda_function.healthcheck.arn
}

# Allow EventBridge to invoke the Lambda.
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.healthcheck.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.healthcheck_schedule.arn
}
