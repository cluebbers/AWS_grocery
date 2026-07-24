output "app_ip" {
  description = "Public IP of the app EC2 instance"
  value       = aws_instance.app.public_ip
}

output "rds_endpoint" {
  description = "RDS endpoint (host:port) for the PostgreSQL database"
  value       = aws_db_instance.postgres.endpoint
}