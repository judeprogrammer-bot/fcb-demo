# Platform 2.0 Pre-Approved Modules

## iam-role — `platform-modules/iam-role/main.tf`

CCF-compliant IAM module. Uses **managed policies only** — no `inline_policy` blocks.

```hcl
resource "aws_iam_role" "this" {
  name = var.role_name
  assume_role_policy = var.assume_role_policy
  # No inline_policy — permissions attached via aws_iam_role_policy_attachment
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}
```

Teams migrated to this module bypass `restrict-iam-inline.sentinel`.

## Other modules

- `platform-modules/s3-secure` — encrypted S3 with bucket policy
- `platform-modules/networking` — VPC with flow logs and restricted egress
- `platform-modules/ecs-service` — ECS service using platform modules
