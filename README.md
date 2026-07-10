# FCB AWS Cloud Platform - Migration Repository

## Overview

This repository contains Infrastructure-as-Code (Terraform) for all application
teams running on FCB's AWS cloud platform. The platform team is migrating from
Platform 1.0 (legacy, direct resource definitions) to Platform 2.0 (pre-approved,
CCF-compliant modules).

## Migration Status

| App Team | Status | Notes |
|----------|--------|-------|
| Payments | NOT STARTED | Legacy ECS + inline IAM, highest risk |
| Fraud Detection | NOT STARTED | Lambda-based, custom KMS, complex IAM |
| Lending | PARTIAL | VPC migrated, IAM still legacy |
| Wealth Management | NOT STARTED | RDS + legacy networking |
| Onboarding | COMPLETE | Fully migrated to 2.0 modules |

## Repository Structure

```
app-teams/           - Each team's application infrastructure
platform-modules/    - Pre-approved 2.0 modules (CCF-compliant)
sentinel-policies/   - HashiCorp Sentinel policy-as-code
.gitlab/             - CI/CD pipeline configuration
```

## Platform 2.0 Requirements

All application teams must:
1. Use modules from `platform-modules/` instead of direct resource definitions
2. Pass all Sentinel hard-fail policies (encryption, tagging)
3. Pass Wiz CICD scan (no high/critical findings, max 5 medium)
4. Use managed IAM policies (no inline policies - triggers Sentinel soft-fail)
5. Restrict egress to approved endpoints only

## CI/CD Workflow

1. Feature branch → MR to `develop`
2. GitLab CI triggers HCP Terraform speculative plan
3. Sentinel policy check (hard-fail + soft-fail)
4. Wiz IO CICD security scan
5. Human code review + merge
6. Apply to non-production landing zone
7. Release bundle → production promotion
