# Sentinel Policy Reference

## restrict-iam-inline.sentinel (SOFT MANDATORY)

**File:** `sentinel-policies/restrict-iam-inline.sentinel`  
**CCF Control:** CCF-IAM-003  
**Type:** Soft-fail — requires Cloud Security manual approval

```python
import "tfplan/v2" as tfplan

iam_roles = filter tfplan.resource_changes as _, rc {
  rc.type is "aws_iam_role" and
  rc.mode is "managed" and
  (rc.change.actions contains "create" or rc.change.actions contains "update")
}

no_inline_policies = rule {
  all iam_roles as _, role {
    role.change.after.inline_policy is null or
    length(role.change.after.inline_policy) is 0
  }
}

main = rule { no_inline_policies }
```

**Advisory output:**
- POLICY: IAM inline policies detected. Requires manual review by Cloud Security.
- RECOMMENDATION: Use `platform-modules/iam-role` which auto-passes this check.

## enforce-encryption.sentinel (HARD MANDATORY)

**File:** `sentinel-policies/enforce-encryption.sentinel`  
Blocks deployment if S3/RDS resources lack encryption.
