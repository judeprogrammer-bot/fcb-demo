# Platform Module: Secure S3 Bucket

**Source:** `platform-modules/s3-secure/main.tf`  
**Version:** 2.0.1  
**CCF Controls:** CCF-ENC-001, CCF-DATA-001, CCF-DATA-002

```hcl
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"
  bucket  = var.bucket_name

  versioning = { enabled = var.enable_versioning }

  # MANDATORY: KMS Encryption (CCF-ENC-001)
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = { sse_algorithm = "aws:kms" }
      bucket_key_enabled = true
    }
  }

  # MANDATORY: Block ALL public access (CCF-DATA-002)
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  logging = {
    target_bucket = "fcb-s3-access-logs-prod"
    target_prefix = "${var.team_name}/${var.bucket_name}/"
  }
}
```

Passes `enforce-encryption.sentinel` and Wiz storage checks automatically.
