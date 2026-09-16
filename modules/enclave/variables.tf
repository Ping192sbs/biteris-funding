
# ═══════════════════════════════════════════════════════════════
# Module: enclave — Input Variables
# Nitro Enclave IAM scaffolding for attested credit pulls.
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
  description = "VPC ID where enclave infrastructure lives"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs where enclave host instances run"
  type        = list(string)
}

# ─── KMS ──────────────────────────────────────────────────────

variable "kms_signing_key_arn" {
  description = "KMS key ARN for signing decision tokens inside the enclave"
  type        = string
}

variable "kms_data_key_arn" {
  description = "KMS key ARN for encrypting enclave configuration and secrets"
  type        = string
}

# ─── TAGS ─────────────────────────────────────────────────────

variable "common_tags" {
  description = "Tags applied to every resource in this module"
  type        = map(string)
}
