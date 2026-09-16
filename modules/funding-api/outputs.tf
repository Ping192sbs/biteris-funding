
# ═══════════════════════════════════════════════════════════════
# Module: funding-api — Outputs
# Values this module returns to the root module.
# ═══════════════════════════════════════════════════════════════

output "alb_arn_suffix" {
  description = "ALB ARN suffix — used by CloudWatch metric dimensions"
  value       = aws_lb.funding.arn_suffix
}

output "alb_dns_name" {
  description = "ALB DNS name — used as the CloudFront origin"
  value       = aws_lb.funding.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID — used for Route 53 alias records"
  value       = aws_lb.funding.zone_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name — used by CloudWatch alarms"
  value       = aws_ecs_cluster.funding.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.funding.arn
}

output "ecs_service_name" {
  description = "ECS service name — used by CloudWatch alarms"
  value       = aws_ecs_service.api.name
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain (d1234.cloudfront.net)"
  value       = aws_cloudfront_distribution.funding.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID — used for Route 53 alias records"
  value       = aws_cloudfront_distribution.funding.hosted_zone_id
}

output "intake_lambda_name" {
  description = "Name of the intake Lambda function"
  value       = aws_lambda_function.intake.function_name
}

output "intake_lambda_arn" {
  description = "ARN of the intake Lambda function"
  value       = aws_lambda_function.intake.arn
}

output "funding_intake_table_name" {
  description = "DynamoDB table name for application intake"
  value       = aws_dynamodb_table.funding_intake.name
}

output "funding_intake_table_arn" {
  description = "DynamoDB table ARN for application intake"
  value       = aws_dynamodb_table.funding_intake.arn
}

output "decision_queue_url" {
  description = "SQS queue URL for the decision pipeline"
  value       = aws_sqs_queue.decision.url
}

output "decision_queue_arn" {
  description = "SQS queue ARN for the decision pipeline"
  value       = aws_sqs_queue.decision.arn
}
