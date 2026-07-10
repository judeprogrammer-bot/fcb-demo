# Payments Team — Legacy Platform 1.0 Infrastructure

**File:** `app-teams/payments/main.tf`  
**Status:** NOT STARTED migration  
**Risk:** HIGH — inline IAM, open egress, no VPC flow logs  
**Owner:** Jeremy Axmacher

## Inline IAM Violations (Sentinel Soft-Fail)

Payments has **3 inline_policy blocks** on IAM roles. These trigger `sentinel-policies/restrict-iam-inline.sentinel` (CCF-IAM-003).

### payments_task role — lines 115-182

```hcl
resource "aws_iam_role" "payments_task" {
  name = "payments-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  # INLINE POLICY - Sentinel soft-fail trigger
  inline_policy {
    name = "payments-s3-access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
          Resource = [aws_s3_bucket.payments_data.arn, "${aws_s3_bucket.payments_data.arn}/*"]
        },
        {
          Effect   = "Allow"
          Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
          Resource = ["*"]  # OVERLY BROAD - Wiz will flag this
        }
      ]
    })
  }

  inline_policy {
    name = "payments-sqs-access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = [aws_sqs_queue.payment_events.arn]
      }]
    })
  }
}
```

### ecs_execution role — lines 184-220

```hcl
resource "aws_iam_role" "ecs_execution" {
  name = "payments-ecs-execution"
  # INLINE POLICY for ECR pull + CloudWatch
  inline_policy {
    name = "ecs-execution-policy"
    policy = jsonencode({ ... })
  }
}
```

## Migration Path

1. Replace `aws_iam_role` resources with `module "iam_role"` from `platform-modules/iam-role`
2. Pass permissions as managed policy ARNs, not inline blocks
3. Re-run HCP Terraform plan — Sentinel soft-fail should clear
