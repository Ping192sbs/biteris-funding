
# ═══════════════════════════════════════════════════════════════
# Module: observability — Outputs
# Values this module returns to the root module.
# ═══════════════════════════════════════════════════════════════

output "sns_topic_arn" {
  description = "SNS topic ARN for on-call alerts — additional subscribers can attach to this"
  value       = aws_sns_topic.oncall.arn
}

output "sns_topic_name" {
  description = "SNS topic name"
  value       = aws_sns_topic.oncall.name
}

output "dashboard_name" {
  description = "CloudWatch dashboard name — view in the AWS console under CloudWatch → Dashboards"
  value       = aws_cloudwatch_dashboard.funding.dashboard_name
}

output "dashboard_url" {
  description = "Direct URL to the CloudWatch dashboard"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.funding.dashboard_name}"
}

output "alarm_arns" {
  description = "ARNs of every CloudWatch alarm created by this module"
  value = [
    aws_cloudwatch_metric_alarm.alb_5xx.arn,
    aws_cloudwatch_metric_alarm.alb_latency.arn,
    aws_cloudwatch_metric_alarm.ecs_cpu.arn,
    aws_cloudwatch_metric_alarm.rds_cpu.arn,
    aws_cloudwatch_metric_alarm.rds_storage.arn,
    aws_cloudwatch_metric_alarm.redis_cpu.arn,
  ]
}

output "alarm_count" {
  description = "Number of CloudWatch alarms created"
  value       = 6
}
