# Lending Platform — Partial Migration

**Source:** `app-teams/lending/main.tf`  
**Status:** PARTIAL — VPC migrated to 2.0, IAM still legacy  
**Risk:** MEDIUM  
**Owner:** Lending Engineering

## What's Migrated (2.0)

VPC uses `terraform-aws-modules/vpc/aws` with flow logs enabled — lines 39-58:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name    = "lending-vpc"
  cidr    = "10.3.0.0/16"

  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
}
```

## What's Still Legacy — Inline IAM (2 blocks)

### lending_api_task role — lines 64-113

```hcl
resource "aws_iam_role" "lending_api_task" {
  name = "lending-api-task-role"

  # STILL USING INLINE POLICY - needs migration to managed policy
  inline_policy {
    name = "lending-api-permissions"
    policy = jsonencode({
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
          Resource = ["arn:aws:s3:::fcb-lending-documents-prod", "..."]
        },
        {
          Effect   = "Allow"
          Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
          Resource = ["*"]  # Still overly broad
        }
      ]
    })
  }
  tags = { MigrationStatus = "pending-iam" }
}
```

### lending_execution role — lines 115-145

Second `inline_policy` block on ECS execution role for ECR/CloudWatch access.

## Next Step

IAM migration only — networking is done. Use `platform-modules/iam-role` for both roles.
