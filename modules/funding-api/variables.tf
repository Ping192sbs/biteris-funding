
# ═══════════════════════════════════════════════════════════════
# Module: funding-api — Input Variables
# The interface between the root module and this module.
# ═══════════════════════════════════════════════════════════════

variable "name_prefix" {
  description = "Naming prefix for all resources (e.g. biteris-funding-prod)"
  type        = string
}

variable "environment" {
  description = "Environment name — dev, staging, or prod"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

# ─── NETWORK ──────────────────────────────────────────────────

variable "vpc_id" {
  description = "VPC ID where the ECS service and ALB will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks and Lambda functions"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the Application Load Balancer"
  type        = list(string)
}

# ─── SECURITY GROUPS ──────────────────────────────────────────

variable "alb_security_group_id" {
  description = "Security group ID to attach to the ALB"
  type        = string
}

variable "ecs_tasks_security_group_id" {
  description = "Security group ID to attach to ECS tasks and Lambda"
  type        = string
}

# ─── KMS ──────────────────────────────────────────────────────

variable "kms_data_key_arn" {
  description = "KMS key ARN for encrypting data at rest"
  type        = string
}

variable "kms_signing_key_arn" {
  description = "KMS key ARN for signing decision tokens"
  type        = string
}

# ─── DATA LAYER ───────────────────────────────────────────────

variable "rds_endpoint" {
  description = "RDS Postgres endpoint address"
  type        = string
}

variable "rds_port" {
  description = "RDS Postgres port"
  type        = number
}

variable "rds_secret_arn" {
  description = "Secrets Manager ARN holding RDS credentials"
  type        = string
}

variable "redis_endpoint" {
  description = "ElastiCache Redis primary endpoint"
  type        = string
}

variable "documents_bucket" {
  description = "S3 bucket name for borrower-uploaded documents"
  type        = string
}

# ─── COMPUTE ──────────────────────────────────────────────────

variable "ecs_task_cpu" {
  description = "ECS task CPU units (1024 = 1 vCPU)"
  type        = number
}

variable "ecs_task_memory" {
  description = "ECS task memory in MB"
  type        = number
}

variable "ecs_desired_count" {
  description = "Baseline number of ECS tasks"
  type        = number
}

# ─── DOMAIN ───────────────────────────────────────────────────

variable "api_fqdn" {
  description = "Fully qualified domain for the API (e.g. api.biteris.net)"
  type        = string
}

variable "apply_fqdn" {
  description = "Fully qualified domain for the borrower app (e.g. apply.biteris.net)"
  type        = string
}

variable "domain_name" {
  description = "Root domain name"
  type        = string
}

variable "waf_arn" {
  description = "WAFv2 WebACL ARN to attach to CloudFront"
  type        = string
}

# ─── TAGS ─────────────────────────────────────────────────────

variable "common_tags" {
  description = "Tags applied to every resource in this module"
  type        = map(string)
}
