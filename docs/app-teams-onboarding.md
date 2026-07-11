# Onboarding — Fully Migrated (Platform 2.0 Reference)

**Source:** `app-teams/onboarding/main.tf`  
**Status:** COMPLETE — passes Sentinel + Wiz  
**Risk:** LOW  
**Owner:** Digital Banking Team

This team is the **gold standard** for migration. No `inline_policy` blocks anywhere.

## 2.0 Networking — lines 41-58

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name    = "onboarding-vpc"
  cidr    = "10.4.0.0/16"

  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
}
```

## 2.0 IAM — Managed Policies Only — lines 62-102

```hcl
module "app_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  role_name               = "onboarding-app-role"
  trusted_role_services   = ["ecs-tasks.amazonaws.com"]
  custom_role_policy_arns = [
    module.s3_policy.arn,
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
  # NO inline_policy — passes restrict-iam-inline.sentinel
}

module "s3_policy" {
  source = "terraform-aws-modules/iam/aws//modules/iam-policy"
  name   = "onboarding-s3-access"
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      Resource = [module.documents_bucket.s3_bucket_arn, "..."]
    }]
  })
}
```

## 2.0 S3 — Encrypted — lines 106-127

```hcl
module "documents_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  bucket = "fcb-onboarding-documents-prod"

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = { sse_algorithm = "aws:kms" }
      bucket_key_enabled = true
    }
  }
  block_public_acls = true
  block_public_policy = true
}
```

## 2.0 Security Group — Restricted Egress — lines 131-160

```hcl
module "app_sg" {
  egress_with_cidr_blocks = [{
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = "0.0.0.0/0"
    description = "HTTPS outbound only"
  }]
  # NO open egress on all ports
}
```
