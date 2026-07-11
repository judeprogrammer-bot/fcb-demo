# Inline IAM Policy Audit (Platform 1.0 Violations)

Cross-team scan for `inline_policy` blocks that trigger Sentinel soft-fail (`restrict-iam-inline.sentinel`).

## Summary

| App Team | File | Inline Policy Count | Status |
|----------|------|---------------------|--------|
| Payments | `app-teams/payments/main.tf` | 3 | NOT STARTED |
| Fraud Detection | `app-teams/fraud-detection/main.tf` | 3 | NOT STARTED |
| Lending | `app-teams/lending/main.tf` | 2 | PARTIAL (VPC done, IAM pending) |
| Wealth Management | `app-teams/wealth-management/main.tf` | 2 | NOT STARTED |
| Onboarding | `app-teams/onboarding/main.tf` | 0 | COMPLETE (uses `platform-modules/iam-role`) |

## Payments — `app-teams/payments/main.tf` (lines 128-179)

```hcl
resource "aws_iam_role" "payments_task" {
  name = "payments-task-role"
  # INLINE POLICY - Sentinel soft-fail trigger
  inline_policy {
    name = "payments-s3-access"
    policy = jsonencode({ ... })
  }
  inline_policy {
    name = "payments-sqs-access"
    policy = jsonencode({ ... })
  }
}
```

## Fraud Detection — `app-teams/fraud-detection/main.tf` (lines 95-137)

```hcl
resource "aws_iam_role" "fraud_lambda" {
  inline_policy {
    name = "fraud-s3-full-access"
    policy = jsonencode({
      Statement = [{ Action = ["s3:*"], Resource = [...] }]
    })
  }
  inline_policy { name = "fraud-dynamodb-access" ... }
  inline_policy { name = "fraud-supporting-services" ... }
}
```

## Lending — `app-teams/lending/main.tf` (lines 77-110)

```hcl
resource "aws_iam_role" "lending_api_task" {
  # STILL USING INLINE POLICY - needs migration to managed policy
  inline_policy {
    name = "lending-api-permissions"
    policy = jsonencode({ ... })
  }
  tags = { MigrationStatus = "pending-iam" }
}
```

## Wealth Management — `app-teams/wealth-management/main.tf` (lines 103-128)

```hcl
resource "aws_iam_role" "wealth_task" {
  inline_policy {
    name = "wealth-data-access"
    policy = jsonencode({ ... })
  }
}
```

## Remediation

Replace inline policies with [platform-modules/iam-role](platform-modules-iam-role.md), which uses managed policies and auto-passes Sentinel.

## Per-Team Docs

- [Payments](app-teams-payments.md) | [Fraud Detection](app-teams-fraud-detection.md) | [Lending](app-teams-lending.md) | [Wealth Management](app-teams-wealth-management.md) | [Onboarding (no violations)](app-teams-onboarding.md)
