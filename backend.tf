
# ═══════════════════════════════════════════════════════════════
# Biteris Funding — Terraform Backend
#
# Terraform stores its "state" (the record of everything it built)
# in an S3 bucket. That bucket must exist BEFORE you run
# `terraform init` — which is why this block is commented out.
#
# Setup instructions:
#
#   1. Bootstrap the backend (see README.md):
#        aws s3api create-bucket --bucket ping192-tfstate-prod --region us-east-1
#        aws s3api put-bucket-versioning --bucket ping192-tfstate-prod \
#          --versioning-configuration Status=Enabled
#        aws dynamodb create-table --table-name ping192-tflock \
#          --attribute-definitions AttributeName=LockID,AttributeType=S \
#          --key-schema AttributeName=LockID,KeyType=HASH \
#          --billing-mode PAY_PER_REQUEST
#
#   2. Uncomment the block below.
#
#   3. Run `terraform init` — Terraform will detect the new backend
#      and offer to migrate any existing local state into S3.
#
# ═══════════════════════════════════════════════════════════════

# terraform {
#   backend "s3" {
#     bucket         = "ping192-tfstate-prod"
#     key            = "biteris-funding/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "ping192-tflock"
#     encrypt        = true
#   }
# }
