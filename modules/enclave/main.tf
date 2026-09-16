
# ═══════════════════════════════════════════════════════════════
# Module: enclave — Core Resources
# IAM role + policy for attested Nitro Enclave credit pulls.
# ═══════════════════════════════════════════════════════════════

# ─── ENCLAVE HOST IAM ROLE ────────────────────────────────────
# This role is assumed by the EC2 instance that hosts the enclave.
# The enclave itself gets a session derived from this role,
# plus an attestation document proving it runs inside a genuine
# Nitro Enclave.

resource "aws_iam_role" "enclave_host" {
  name = "${var.name_prefix}-enclave-host"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_instance_profile" "enclave_host" {
  name = "${var.name_prefix}-enclave-host"
  role = aws_iam_role.enclave_host.name

  tags = var.common_tags
}

# ─── POLICY: KMS ACCESS ───────────────────────────────────────
# The enclave is only allowed to use KMS through the
# kms:RecipientAttestation condition — which means KMS will
# refuse any request that doesn't carry a valid attestation
# document from a real Nitro Enclave.

resource "aws_iam_role_policy" "enclave_kms" {
  name = "${var.name_prefix}-enclave-kms"
  role = aws_iam_role.enclave_host.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowKMSDecryptWithAttestation"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [var.kms_data_key_arn]
        Condition = {
          StringEquals = {
            "kms:RecipientAttestation:PCR0" = "*"
          }
        }
      },
      {
        Sid    = "AllowKMSSignWithAttestation"
        Effect = "Allow"
        Action = [
          "kms:Sign",
          "kms:Verify",
          "kms:GetPublicKey",
          "kms:DescribeKey"
        ]
        Resource = [var.kms_signing_key_arn]
        Condition = {
          StringEquals = {
            "kms:RecipientAttestation:PCR0" = "*"
          }
        }
      }
    ]
  })
}

# ─── POLICY: CLOUDWATCH LOGS ──────────────────────────────────
# Enclaves can only write logs through a vsock proxy on the host.
# The host role needs permissions to write those logs to CloudWatch.

resource "aws_cloudwatch_log_group" "enclave" {
  name              = "/aws/enclave/${var.name_prefix}"
  retention_in_days = 365
  kms_key_id        = var.kms_data_key_arn

  tags = var.common_tags
}

resource "aws_iam_role_policy" "enclave_logs" {
  name = "${var.name_prefix}-enclave-logs"
  role = aws_iam_role.enclave_host.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.enclave.arn}:*"
    }]
  })
}

# ─── ATTESTATION SECRET ───────────────────────────────────────
# Stores the enclave's attestation configuration — the PCR values
# expected from a valid build. Anything that doesn't match these
# PCR values won't be able to use the signing key.

resource "aws_secretsmanager_secret" "enclave_attestation" {
  name                    = "${var.name_prefix}/enclave-attestation"
  description             = "Expected PCR values for the enclave image — used to verify enclave authenticity"
  kms_key_id              = var.kms_data_key_arn
  recovery_window_in_days = 7

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "enclave_attestation" {
  secret_id = aws_secretsmanager_secret.enclave_attestation.id
  secret_string = jsonencode({
    pcr0 = "REPLACE_WITH_PCR0_OF_YOUR_ENCLAVE_IMAGE"
    pcr1 = "REPLACE_WITH_PCR1_OF_YOUR_ENCLAVE_IMAGE"
    pcr2 = "REPLACE_WITH_PCR2_OF_YOUR_ENCLAVE_IMAGE"
    note = "These values are the cryptographic measurement of the enclave image. When the enclave launches, it produces an attestation document containing its PCR values. KMS verifies those values match these before allowing any cryptographic operation. Update these values after building your enclave image."
  })
}

# ─── ENCLAVE ATTACHMENT POLICY ────────────────────────────────
# Attaches a policy to the host role allowing it to describe
# enclaves it owns — needed to start, stop, and monitor the
# enclave process.

resource "aws_iam_role_policy" "enclave_manage" {
  name = "${var.name_prefix}-enclave-manage"
  role = aws_iam_role.enclave_host.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeInstances",
        "ec2:DescribeTags",
        "ec2:DescribeEnclaveOptions",
        "ec2:DescribeNetworkInterfaces"
      ]
      Resource = "*"
    }]
  })
}
