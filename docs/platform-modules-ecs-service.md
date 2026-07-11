# Platform Module: ECS Fargate Service

**Source:** `platform-modules/ecs-service/main.tf`  
**Version:** 2.0.0

Standard Fargate deployment with encrypted logs and managed execution role.

```hcl
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.service_name}"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn  # Passes enforce-encryption Sentinel policy
}

resource "aws_iam_role" "execution" {
  name = "${var.service_name}-execution"
  assume_role_policy = jsonencode({ ... })
  # MANAGED POLICY - no inline, passes Sentinel
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "this" {
  family             = var.service_name
  execution_role_arn = aws_iam_role.execution.arn
  task_role_arn      = var.task_role_arn  # From platform-modules/iam-role
  network_mode       = "awsvpc"
  requires_compatibilities = ["FARGATE"]
}
```

## Dependencies

- `task_role_arn` must come from `platform-modules/iam-role`
- `subnet_ids` and `security_group_ids` from `platform-modules/networking`
