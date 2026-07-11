# FCB Platform CI/CD Pipeline

**Source:** `.gitlab/ci-template.yml`  
**Workflow:** Plan → Sentinel → Wiz → Review → Apply

All app teams include this template in their `.gitlab-ci.yml`.

## Pipeline Stages

```yaml
stages:
  - validate
  - plan
  - security
  - apply
```

## HCP Terraform Speculative Plan — lines 29-40

```yaml
terraform-plan:
  stage: plan
  script:
    - echo "Triggering speculative plan in HCP Terraform..."
    - echo "Workspace: ${TFC_WORKSPACE}"
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
```

## Sentinel Policy Check — lines 43-53

```yaml
sentinel-check:
  stage: security
  script:
    - echo "Hard-fail policies: enforce-encryption, enforce-tagging"
    - echo "Soft-fail policies: restrict-iam-inline, restrict-public-access"
    - sentinel apply -config=sentinel-policies/
  allow_failure: false
```

## Wiz IO CICD Scan — lines 56-65

```yaml
wiz-security-scan:
  stage: security
  script:
    - echo "Rules: High/Critical = FAIL, Medium <= 5 = PASS"
    - wiz-cli iac scan --path . --policy "FCB-IaC-Policy"
```

## Apply to Non-Production — lines 68-78

Manual apply on merge to `develop` branch only.
