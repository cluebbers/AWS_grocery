terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Applied automatically to every resource that supports tags.
  default_tags {
    tags = {
      Project   = "grocerymate"
      ManagedBy = "terraform"
    }
  }
}

# Variables

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-central-1"
}

variable "instance_type" {
  description = "EC2 instance type for the app server"
  type        = string
  default     = "t2.micro"
}

variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "grocerymate_db"
}

variable "db_username" {
  description = "Master username for the RDS database"
  type        = string
  default     = "grocery_user"
}

variable "db_password" {
  description = "Master password for the RDS database"
  type        = string
  sensitive   = true
}

variable "my_ip" {
  description = "My IP (CIDR) allowed to SSH into the EC2 instance"
  type        = string
}

variable "alert_email" {
  description = "Email address that receives EC2 health alerts (you must confirm the SNS subscription email)"
  type        = string
}
