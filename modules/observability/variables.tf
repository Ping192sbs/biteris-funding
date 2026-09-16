
# ═══════════════════════════════════════════════════════════════
# Module: observability — Input Variables
# CloudWatch alarms, SNS on-call, dashboard.
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

# ─── METRIC SOURCES ───────────────────────────────────────────

variable "alb_arn_suffix" {
  description = "ALB ARN suffix — CloudWatch dimension for ApplicationELB metrics"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name — CloudWatch dimension for ECS metrics"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name — CloudWatch dimension for ECS metrics"
  type        = string
}

variable "rds_instance_id" {
  description = "RDS instance identifier — CloudWatch dimension for RDS metrics"
  type        = string
}

variable "redis_replication_group" {
  description = "ElastiCache replication group ID — CloudWatch dimension for ElastiCache metrics"
  type        = string
}

# ─── ALERTING ─────────────────────────────────────────────────

variable "alarm_email" {
  description = "Email address for SNS alarm notifications"
  type        = string
}

# ─── SECURITY ─────────────────────────────────────────────────

variable "kms_audit_key_arn" {
  description = "KMS key ARN used to encrypt the SNS topic"
  type        = string
}

# ─── TAGS ─────────────────────────────────────────────────────

variable "common_tags" {
  description = "Tags applied to every resource in this module"
  type        = map(string)
}
