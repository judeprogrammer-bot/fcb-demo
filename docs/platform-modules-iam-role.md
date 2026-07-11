# Platform Module: IAM Role

**Source:** `platform-modules/iam-role/main.tf`  
**Version:** 2.1.0  
**Maintainer:** Platform Engineering (Jeremy Axmacher)

Pre-approved IAM module. Uses **managed policies only** — bypasses `restrict-iam-inline.sentinel`.

```hcl
resource "aws_iam_role" "this" {
  name = var.role_name
  assume_role_policy = jsonencode({ ... })

  # NO INLINE POLICIES - passes Sentinel restrict-iam-inline policy
  tags = {
    Platform   = "2.0"
    Module     = "platform-modules/iam-role"
    Compliance = "sentinel-approved"
  }
}

resource "aws_iam_policy" "this" {
  name   = "${var.role_name}-policy"
  policy = jsonencode({
    Statement = [for stmt in var.policy_statements : {
      Sid      = stmt.sid
      Effect   = stmt.effect
      Action   = stmt.actions
      Resource = stmt.resources
    }]
  })
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}
```

## Usage Example

```hcl
module "payments_task_role" {
  source = "../../platform-modules/iam-role"
  role_name = "payments-task-role"
  policy_statements = [{
    sid       = "S3Access"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["arn:aws:s3:::fcb-payments-data-prod/*"]
  }]
}
```
