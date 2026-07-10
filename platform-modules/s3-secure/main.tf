# =============================================================================
# Platform Module: Secure S3 Bucket
# Version: 2.0.1
# Description: S3 bucket with encryption, versioning, public access blocked,
#              and access logging. Passes Sentinel + Wiz automatically.
# Maintainer: Platform Engineering
# =============================================================================

variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
}

variable "team_name" {
  description = "Owning team name"
  type        = string
}

variable "enable_versioning" {
  description = "Enable object versioning"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  bucket = var.bucket_name

  # MANDATORY: Versioning (CCF-DATA-001)
  versioning = { enabled = var.enable_versioning }

  # MANDATORY: KMS Encryption (CCF-ENC-001)
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "aws:kms"
      }
      bucket_key_enabled = true
    }
  }

  # MANDATORY: Block ALL public access (CCF-DATA-002)
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # Access logging
  logging = {
    target_bucket = "fcb-s3-access-logs-prod"
    target_prefix = "${var.team_name}/${var.bucket_name}/"
  }

  tags = merge(var.tags, {
    Platform   = "2.0"
    Module     = "platform-modules/s3-secure"
    Team       = var.team_name
    Compliance = "CCF-ENC-001,CCF-DATA-002"
  })
}

output "bucket_arn" {
  value = module.s3_bucket.s3_bucket_arn
}

output "bucket_id" {
  value = module.s3_bucket.s3_bucket_id
}
