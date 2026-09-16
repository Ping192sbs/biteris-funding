
# ═══════════════════════════════════════════════════════════════
# Biteris Funding — Root Input Variables
# Every value the root module accepts.
# ═══════════════════════════════════════════════════════════════

variable "region" {
  description = "Primary AWS region where infrastructure is deployed"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name — must be dev, staging, or prod"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "domain_name" {
  description = "Root domain for the platform (must have a Route 53 hosted zone)"
  type        = string
  default     = "biteris.net"
}

variable "api_subdomain" {
  description = "Subdomain for the API endpoint"
  type        = string
  default     = "api"
}

variable "apply_subdomain" {
  description = "Subdomain for the borrower-facing application"
  type        = string
  default     = "apply"
}

variable "rds_instance_class" {
  description = "RDS instance type. db.r6g.xlarge is production. db.t4g.medium is dev."
  type        = string
  default     = "db.r6g.xlarge"
}

variable "rds_allocated_storage" {
  description = "RDS storage in GB. Auto-scales up to 2x this value."
  type        = number
  default     = 500

  validation {
    condition     = var.rds_allocated_storage >= 100
    error_message = "RDS storage must be at least 100 GB."
  }
}

variable "redis_node_type" {
  description = "ElastiCache node type. cache.r7g.large is production."
  type        = string
  default     = "cache.r7g.large"
}

variable "ecs_task_cpu" {
  description = "ECS task CPU units (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "ecs_task_memory" {
  description = "ECS task memory in MB"
  type        = number
  default     = 2048
}

variable "ecs_desired_count" {
  description = "Baseline number of ECS tasks. Auto-scales from here."
  type        = number
  default     = 3
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
  default     = "oncall@biteris.net"
}
