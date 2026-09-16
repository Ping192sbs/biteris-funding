
# ═══════════════════════════════════════════════════════════════
# Module: funding-api — Core Resources
# DynamoDB, SQS, Lambda, ECS, ALB, CloudFront
# ═══════════════════════════════════════════════════════════════

# ─── DYNAMODB ─────────────────────────────────────────────────
resource "aws_dynamodb_table" "funding_intake" {
  name         = "funding_intake"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "application_id"

  attribute {
    name = "application_id"
    type = "S"
  }

  attribute {
    name = "borrower_id"
    type = "S"
  }

  global_secondary_index {
    name            = "borrower_id-index"
    hash_key        = "borrower_id"
    projection_type = "ALL"
  }

  point_in_time_recovery { enabled = true }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_data_key_arn
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = merge(var.common_tags, { Name = "funding_intake" })
}

resource "aws_dynamodb_table" "decision_queue" {
  name         = "funding_decision_table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "decision_id"

  attribute {
    name = "decision_id"
    type = "S"
  }

  point_in_time_recovery { enabled = true }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_data_key_arn
  }

  tags = merge(var.common_tags, { Name = "funding_decision" })
}

# ─── SQS ──────────────────────────────────────────────────────
resource "aws_sqs_queue" "decision_dlq" {
  name                      = "funding_decision_dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = var.kms_data_key_arn

  tags = var.common_tags
}

resource "aws_sqs_queue" "decision" {
  name                       = "funding_decision"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  kms_master_key_id          = var.kms_data_key_arn

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.decision_dlq.arn
    maxReceiveCount     = 3
  })

  tags = var.common_tags
}

# ─── IAM: LAMBDA EXECUTION ────────────────────────────────────
resource "aws_iam_role" "lambda_exec" {
  name = "${var.name_prefix}-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_funding" {
  name = "${var.name_prefix}-lambda-funding"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.funding_intake.arn,
          "${aws_dynamodb_table.funding_intake.arn}/index/*",
          aws_dynamodb_table.decision_queue.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.decision.arn,
          aws_sqs_queue.decision_dlq.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${var.documents_bucket}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:Sign",
          "kms:Verify"
        ]
        Resource = [
          var.kms_data_key_arn,
          var.kms_signing_key_arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [var.rds_secret_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:*:*"
      }
    ]
  })
}

# ─── LAMBDA: INTAKE HANDLER ───────────────────────────────────
resource "aws_cloudwatch_log_group" "intake" {
  name              = "/aws/lambda/${var.name_prefix}-intake"
  retention_in_days = 365
  kms_key_id        = var.kms_data_key_arn

  tags = var.common_tags
}

data "archive_file" "intake" {
  type        = "zip"
  output_path = "${path.module}/.build/intake.zip"

  source {
    filename = "index.js"
    content  = <<-EOT
      // Biteris Funding — intake handler (placeholder)
      // Replace with production code that:
      //   1. Validates the incoming payload against a schema
      //   2. Computes a canonical SHA-256 hash
      //   3. Signs the hash with KMS (RSA-4096)
      //   4. Writes ciphertext to S3
      //   5. Writes index metadata to DynamoDB
      //   6. Enqueues the application to SQS

      exports.handler = async (event) => {
        return {
          statusCode: 200,
          body: JSON.stringify({ ok: true, service: 'biteris-funding-intake' })
        };
      };
    EOT
  }
}

resource "aws_lambda_function" "intake" {
  function_name    = "${var.name_prefix}-intake"
  role             = aws_iam_role.lambda_exec.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 30
  filename         = data.archive_file.intake.output_path
  source_code_hash = data.archive_file.intake.output_base64sha256
  kms_key_arn      = var.kms_data_key_arn

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.ecs_tasks_security_group_id]
  }

  environment {
    variables = {
      INTAKE_TABLE   = aws_dynamodb_table.funding_intake.name
      DECISION_TABLE = aws_dynamodb_table.decision_queue.name
      DECISION_QUEUE = aws_sqs_queue.decision.url
      DOCS_BUCKET    = var.documents_bucket
      RDS_SECRET     = var.rds_secret_arn
    }
  }

  tracing_config { mode = "Active" }

  depends_on = [
    aws_cloudwatch_log_group.intake,
    aws_iam_role_policy.lambda_funding
  ]

  tags = var.common_tags
}

# ─── ECS CLUSTER ──────────────────────────────────────────────
resource "aws_ecs_cluster" "funding" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "funding" {
  cluster_name       = aws_ecs_cluster.funding.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# ─── ECS IAM ROLES ────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/ecs/${var.name_prefix}/api"
  retention_in_days = 365
  kms_key_id        = var.kms_data_key_arn

  tags = var.common_tags
}

resource "aws_iam_role" "ecs_execution" {
  name = "${var.name_prefix}-ecs-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "${var.name_prefix}-ecs-secrets"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "kms:Decrypt"
      ]
      Resource = [var.rds_secret_arn, var.kms_data_key_arn]
    }]
  })
}

resource "aws_iam_role" "ecs_task" {
  name = "${var.name_prefix}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "ecs_task" {
  name = "${var.name_prefix}-ecs-task-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${var.documents_bucket}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:Sign",
          "kms:Verify"
        ]
        Resource = [
          var.kms_data_key_arn,
          var.kms_signing_key_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.funding_intake.arn,
          "${aws_dynamodb_table.funding_intake.arn}/index/*"
        ]
      }
    ]
  })
}

# ─── ECS TASK + SERVICE ───────────────────────────────────────
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.name_prefix}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "api"
    image     = "public.ecr.aws/nginx/nginx:stable"
    essential = true

    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]

    environment = [
      { name = "NODE_ENV",    value = "production" },
      { name = "AWS_REGION",  value = var.region },
      { name = "RDS_HOST",    value = var.rds_endpoint },
      { name = "RDS_PORT",    value = tostring(var.rds_port) },
      { name = "REDIS_HOST",  value = var.redis_endpoint },
      { name = "DOCS_BUCKET", value = var.documents_bucket }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.api.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "api"
      }
    }
  }])

  tags = var.common_tags
}

resource "aws_ecs_service" "api" {
  name            = "${var.name_prefix}-api"
  cluster         = aws_ecs_cluster.funding.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_tasks_security_group_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 8080
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = var.common_tags
}

# ─── AUTO-SCALING ─────────────────────────────────────────────
resource "aws_appautoscaling_target" "api" {
  max_capacity       = 40
  min_capacity       = var.ecs_desired_count
  resource_id        = "service/${aws_ecs_cluster.funding.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "api_cpu" {
  name               = "${var.name_prefix}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api.resource_id
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ─── ALB ──────────────────────────────────────────────────────
resource "aws_lb" "funding" {
  name                       = "${var.name_prefix}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.alb_security_group_id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
  enable_deletion_protection = true
  enable_http2               = true

  tags = var.common_tags
}

resource "aws_lb_target_group" "api" {
  name        = "${var.name_prefix}-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = var.common_tags
}

# ─── CLOUDFRONT ───────────────────────────────────────────────
resource "aws_cloudfront_distribution" "funding" {
  enabled = true
  aliases = [var.api_fqdn, var.apply_fqdn]

  origin {
    domain_name = aws_lb.funding.dns_name
    origin_id   = "funding-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "funding-alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies { forward = "all" }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  web_acl_id = var.waf_arn

  tags = var.common_tags
}
