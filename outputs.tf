
# ═══════════════════════════════════════════════════════════════
# Biteris Funding — Outputs
# What Terraform prints back after a successful apply.
# ═══════════════════════════════════════════════════════════════

output "api_endpoint" {
  description = "Public API endpoint (via CloudFront)"
  value       = "https://${local.api_fqdn}"
}

output "apply_endpoint" {
  description = "Borrower-facing application endpoint (via CloudFront)"
  value       = "https://${local.apply_fqdn}"
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = module.funding_api.cloudfront_domain_name
}

output "rds_endpoint" {
  description = "RDS Postgres endpoint (private — reachable only from inside the VPC)"
  value       = aws_db_instance.funding.address
  sensitive   = true
}

output "rds_port" {
  description = "RDS Postgres port"
  value       = aws_db_instance.funding.port
}

output "documents_bucket" {
  description = "S3 bucket for borrower-uploaded documents"
  value       = aws_s3_bucket.documents.id
}

output "audit_chain_bucket" {
  description = "S3 bucket for the immutable audit chain"
  value       = aws_s3_bucket.audit_chain.id
}

output "kms_data_key_arn" {
  description = "KMS key ARN for data-at-rest encryption"
  value       = aws_kms_key.funding_data.arn
}

output "kms_signing_key_arn" {
  description = "KMS key ARN for signing decision tokens"
  value       = aws_kms_key.funding_signing.arn
}

output "kms_audit_key_arn" {
  description = "KMS key ARN for signing the audit chain"
  value       = aws_kms_key.audit_chain.arn
}

output "waf_arn" {
  description = "WAFv2 WebACL ARN"
  value       = aws_wafv2_web_acl.funding_waf.arn
}
