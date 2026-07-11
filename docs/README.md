# FCB Migration Documentation Index

Context7 indexes these markdown files. Each doc maps to Terraform/Sentinel source in the repo.

## App Teams (5)

| Team | Source File | Doc | Migration Status |
|------|-------------|-----|------------------|
| Payments | `app-teams/payments/main.tf` | [app-teams-payments.md](app-teams-payments.md) | NOT STARTED |
| Fraud Detection | `app-teams/fraud-detection/main.tf` | [app-teams-fraud-detection.md](app-teams-fraud-detection.md) | NOT STARTED |
| Lending | `app-teams/lending/main.tf` | [app-teams-lending.md](app-teams-lending.md) | PARTIAL |
| Wealth Management | `app-teams/wealth-management/main.tf` | [app-teams-wealth-management.md](app-teams-wealth-management.md) | NOT STARTED |
| Onboarding | `app-teams/onboarding/main.tf` | [app-teams-onboarding.md](app-teams-onboarding.md) | COMPLETE |

## Platform Modules (4)

| Module | Source File | Doc |
|--------|-------------|-----|
| IAM Role | `platform-modules/iam-role/main.tf` | [platform-modules-iam-role.md](platform-modules-iam-role.md) |
| S3 Secure | `platform-modules/s3-secure/main.tf` | [platform-modules-s3-secure.md](platform-modules-s3-secure.md) |
| Networking | `platform-modules/networking/main.tf` | [platform-modules-networking.md](platform-modules-networking.md) |
| ECS Service | `platform-modules/ecs-service/main.tf` | [platform-modules-ecs-service.md](platform-modules-ecs-service.md) |

## Sentinel Policies (2)

| Policy | Source File | Doc |
|--------|-------------|-----|
| restrict-iam-inline | `sentinel-policies/restrict-iam-inline.sentinel` | [sentinel-policies.md](sentinel-policies.md) |
| enforce-encryption | `sentinel-policies/enforce-encryption.sentinel` | [sentinel-policies.md](sentinel-policies.md) |

## CI/CD

| File | Doc |
|------|-----|
| `.gitlab/ci-template.yml` | [ci-pipeline.md](ci-pipeline.md) |

## Cross-Team Audits

- [inline-iam-audit.md](inline-iam-audit.md) — all teams with `inline_policy` violations
