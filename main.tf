
# ═══════════════════════════════════════════════════════════════
# Biteris Funding — Global Direct Lending Platform
# Root module · Managed by PING192
# ═══════════════════════════════════════════════════════════════

locals {
  name_prefix = "biteris-funding-${var.environment}"
  api_fqdn    = "${var.api_subdomain}.${var.domain_name}"
  apply_fqdn  = "${var.apply_subdomain}.${var.domain_name}"

  common_tags = {
    Project     = "biteris-funding"
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "ping192-platform-team"
  }
}

# ─── KMS ──────────────────────────────────────────────────────
resource "aws_kms_key" "funding_data" {
  description             = "Biteris Funding — data encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region            = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-data" })
}

resource "aws_kms_alias" "funding_data" {
  name          = "alias/${local.name_prefix}-data"
  target_key_id = aws_kms_key.funding_data.key_id
}

resource "aws_kms_key" "funding_signing" {
  description              = "Asymmetric signing key for decision tokens"
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "RSA_4096"
  deletion_window_in_days  = 30
  enable_key_rotation      = true
  multi_region             = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-signing" })
}

resource "aws_kms_key" "audit_chain" {
  description              = "Immutable audit chain signing key"
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "RSA_4096"
  deletion_window_in_days  = 30
  enable_key_rotation      = true
  multi_region             = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-audit" })
}

# ─── VPC ──────────────────────────────────────────────────────
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.1"

  name = "${local.name_prefix}-vpc"
  cidr = "10.42.0.0/16"

  azs              = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets  = ["10.42.1.0/24", "10.42.2.0/24", "10.42.3.0/24"]
  public_subnets   = ["10.42.101.0/24", "10.42.102.0/24", "10.42.103.0/24"]
  database_subnets = ["10.42.201.0/24", "10.42.202.0/24", "10.42.203.0/24"]

  enable_nat_gateway     = true
  one_nat_gateway_per_az = true
  enable_dns_hostnames   = true
  enable_dns_support     = true
  enable_flow_log        = true

  tags = local.common_tags
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = local.common_tags
}

# ─── SECURITY GROUPS ──────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "ALB ingress"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  tags = local.common_tags
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${local.name_prefix}-ecs-tasks-sg"
  description = "ECS task traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "RDS ingress from ECS only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  tags = local.common_tags
}

resource "aws_security_group" "redis" {
  name        = "${local.name_prefix}-redis-sg"
  description = "Redis ingress from ECS only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  tags = local.common_tags
}

# ─── RDS ──────────────────────────────────────────────────────
resource "random_password" "rds" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>?"
}

resource "aws_db_subnet_group" "rds" {
  name       = "${local.name_prefix}-rds-subnet"
  subnet_ids = module.vpc.database_subnets

  tags = local.common_tags
}

resource "aws_db_parameter_group" "rds" {
  name   = "${local.name_prefix}-pg15"
  family = "postgres15"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = local.common_tags
}

resource "aws_db_instance" "funding" {
  identifier = "${local.name_prefix}-db"

  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.rds_instance_class

  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true
  storage_kms_key_id    = aws_kms_key.funding_data.arn

  db_name  = "biteris_funding"
  username = "funding_admin"
  password = random_password.rds.result

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.rds.name

  backup_retention_period = 30
  backup_window           = "03:00-04:00"

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.funding_data.arn
  performance_insights_retention_period = 731

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  deletion_protection = true
  skip_final_snapshot = false

  auto_minor_version_upgrade = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-db" })

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

resource "aws_secretsmanager_secret" "rds_password" {
  name                    = "${local.name_prefix}/rds-password"
  kms_key_id              = aws_kms_key.funding_data.arn
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "rds_password" {
  secret_id = aws_secretsmanager_secret.rds_password.id
  secret_string = jsonencode({
    username = aws_db_instance.funding.username
    password = random_password.rds.result
    host     = aws_db_instance.funding.address
    port     = aws_db_instance.funding.port
    dbname   = aws_db_instance.funding.db_name
  })
}

# ─── ELASTICACHE REDIS ────────────────────────────────────────
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name_prefix}-redis-subnet"
  subnet_ids = module.vpc.private_subnets

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "redis_slow" {
  name              = "/aws/elasticache/${local.name_prefix}/slow-log"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.funding_data.arn

  tags = local.common_tags
}

resource "aws_elasticache_replication_group" "funding_cache" {
  replication_group_id = "${local.name_prefix}-cache"
  description          = "Session + decision token cache"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.redis_node_type
  num_cache_clusters   = 3
  parameter_group_name = "default.redis7"
  port                 = 6379

  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  kms_key_id                 = aws_kms_key.funding_data.arn

  snapshot_retention_limit = 7
  snapshot_window          = "05:00-06:00"

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-cache" })
}

# ─── S3 ───────────────────────────────────────────────────────
resource "random_id" "bucket" {
  byte_length = 4
}

resource "aws_s3_bucket" "documents" {
  bucket = "${local.name_prefix}-docs-${random_id.bucket.hex}"

  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-documents"
    DataClass = "pii-encrypted"
    Retention = "7-years"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.funding_data.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket                  = aws_s3_bucket.documents.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_object_lock_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id
  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = 2555
    }
  }
}

resource "aws_s3_bucket" "audit_chain" {
  bucket = "${local.name_prefix}-audit-${random_id.bucket.hex}"

  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-audit"
    Retention = "7-years"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_chain" {
  bucket = aws_s3_bucket.audit_chain.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.audit_chain.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "audit_chain" {
  bucket                  = aws_s3_bucket.audit_chain.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "audit_chain" {
  bucket = aws_s3_bucket.audit_chain.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_object_lock_configuration" "audit_chain" {
  bucket = aws_s3_bucket.audit_chain.id
  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = 2555
    }
  }
}

# ─── CLOUDTRAIL ───────────────────────────────────────────────
resource "aws_cloudtrail" "registry_trail" {
  name                          = "${local.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.audit_chain.id
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.audit_chain.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = local.common_tags

  depends_on = [aws_s3_bucket_policy.audit_chain]
}

resource "aws_s3_bucket_policy" "audit_chain" {
  bucket = aws_s3_bucket.audit_chain.id
  policy = data.aws_iam_policy_document.audit_chain.json
}

data "aws_iam_policy_document" "audit_chain" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.audit_chain.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.audit_chain.arn}/cloudtrail/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.audit_chain.arn,
      "${aws_s3_bucket.audit_chain.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# ─── WAF ──────────────────────────────────────────────────────
resource "aws_wafv2_web_acl" "funding_waf" {
  name  = "${local.name_prefix}-waf"
  scope = "REGIONAL"

  default_action { allow {} }

  rule {
    name     = "rate-limit"
    priority = 1
    action { block {} }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-common"
    priority = 2
    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-bad-inputs"
    priority = 3
    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-sqli"
    priority = 4
    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-sqli"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = local.common_tags
}

# ─── MODULES ──────────────────────────────────────────────────
module "funding_api" {
  source = "./modules/funding-api"

  name_prefix                 = local.name_prefix
  environment                 = var.environment
  region                      = var.region
  vpc_id                      = module.vpc.vpc_id
  private_subnet_ids          = module.vpc.private_subnets
  public_subnet_ids           = module.vpc.public_subnets
  alb_security_group_id       = aws_security_group.alb.id
  ecs_tasks_security_group_id = aws_security_group.ecs_tasks.id

  kms_data_key_arn    = aws_kms_key.funding_data.arn
  kms_signing_key_arn = aws_kms_key.funding_signing.arn

  rds_endpoint     = aws_db_instance.funding.address
  rds_port         = aws_db_instance.funding.port
  rds_secret_arn   = aws_secretsmanager_secret.rds_password.arn
  redis_endpoint   = aws_elasticache_replication_group.funding_cache.primary_endpoint_address
  documents_bucket = aws_s3_bucket.documents.id

  ecs_task_cpu      = var.ecs_task_cpu
  ecs_task_memory   = var.ecs_task_memory
  ecs_desired_count = var.ecs_desired_count

  api_fqdn    = local.api_fqdn
  apply_fqdn  = local.apply_fqdn
  domain_name = var.domain_name
  waf_arn     = aws_wafv2_web_acl.funding_waf.arn

  common_tags = local.common_tags
}

module "observability" {
  source = "./modules/observability"

  name_prefix             = local.name_prefix
  environment             = var.environment
  region                  = var.region
  alb_arn_suffix          = module.funding_api.alb_arn_suffix
  ecs_cluster_name        = module.funding_api.ecs_cluster_name
  ecs_service_name        = module.funding_api.ecs_service_name
  rds_instance_id         = aws_db_instance.funding.identifier
  redis_replication_group = aws_elasticache_replication_group.funding_cache.replication_group_id
  alarm_email             = var.alarm_email
  kms_audit_key_arn       = aws_kms_key.audit_chain.arn

  common_tags = local.common_tags
}

module "enclave" {
  source = "./modules/enclave"

  name_prefix         = local.name_prefix
  environment         = var.environment
  region              = var.region
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnets
  kms_signing_key_arn = aws_kms_key.funding_signing.arn
  kms_data_key_arn    = aws_kms_key.funding_data.arn

  common_tags = local.common_tags
}
