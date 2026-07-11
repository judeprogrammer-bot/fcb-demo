# Sentinel Policy Reference

## restrict-iam-inline.sentinel (SOFT MANDATORY)

**Source:** `sentinel-policies/restrict-iam-inline.sentinel`  
**CCF Control:** CCF-IAM-003

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

**Advisory:** Use `platform-modules/iam-role` to bypass Cloud Security manual review.

---

## enforce-encryption.sentinel (HARD MANDATORY)

**Source:** `sentinel-policies/enforce-encryption.sentinel`  
**CCF Control:** CCF-ENC-001  
**Blocks:** `terraform apply` on failure

```python
import "tfplan/v2" as tfplan

sqs_queues = filter tfplan.resource_changes as _, rc {
  rc.type is "aws_sqs_queue" and rc.mode is "managed"
}

sqs_encrypted = rule {
  all sqs_queues as _, queue {
    queue.change.after.kms_master_key_id is not null and
    queue.change.after.kms_master_key_id is not ""
  }
}

sns_topics = filter tfplan.resource_changes as _, rc {
  rc.type is "aws_sns_topic" and rc.mode is "managed"
}

sns_encrypted = rule {
  all sns_topics as _, topic {
    topic.change.after.kms_master_key_id is not null
  }
}

log_groups = filter tfplan.resource_changes as _, rc {
  rc.type is "aws_cloudwatch_log_group" and rc.mode is "managed"
}

logs_encrypted = rule {
  all log_groups as _, lg {
    lg.change.after.kms_key_id is not null
  }
}

main = rule {
  sqs_encrypted and sns_encrypted and logs_encrypted
}
```

**Fix:** Use `platform-modules/s3-secure` and `platform-modules/ecs-service` which set KMS encryption by default.
