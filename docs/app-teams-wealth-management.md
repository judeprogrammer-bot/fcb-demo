# Wealth Management — Legacy Platform 1.0

**Source:** `app-teams/wealth-management/main.tf`  
**Status:** NOT STARTED  
**Risk:** MEDIUM — RDS + legacy networking  
**Owner:** Wealth Management Engineering

## Legacy Networking — lines 31-50

Direct VPC resource definitions, **no flow logs**:

```hcl
resource "aws_vpc" "wealth" {
  cidr_block           = "10.5.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  # MISSING: VPC flow logs
  tags = { Name = "wealth-mgmt-vpc", Team = "wealth-management" }
}
```

## Inline IAM Violations (2 blocks)

### wealth_task role — lines 91-129

```hcl
resource "aws_iam_role" "wealth_task" {
  name = "wealth-portal-task-role"

  inline_policy {
    name = "wealth-data-access"
    policy = jsonencode({
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:ListBucket"]
          Resource = ["arn:aws:s3:::fcb-wealth-client-data-prod", "..."]
        },
        {
          Effect   = "Allow"
          Action   = ["kms:Decrypt"]
          Resource = ["*"]
        }
      ]
    })
  }
}
```

### wealth_execution role — lines 131-160

```hcl
resource "aws_iam_role" "wealth_execution" {
  inline_policy {
    name = "execution-permissions"
    policy = jsonencode({ ... })
  }
}
```

## Migration Path

1. Replace VPC with `platform-modules/networking`
2. Replace IAM with `platform-modules/iam-role`
3. Migrate RDS to encrypted configuration per `enforce-encryption.sentinel`
