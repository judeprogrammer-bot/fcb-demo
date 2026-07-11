# Platform 2.0 Pre-Approved Modules

See individual module docs (each maps to a `platform-modules/*/main.tf` source file):

- [iam-role](platform-modules-iam-role.md) — managed IAM policies, no inline
- [s3-secure](platform-modules-s3-secure.md) — encrypted S3, public access blocked
- [networking](platform-modules-networking.md) — VPC with flow logs, restricted egress
- [ecs-service](platform-modules-ecs-service.md) — Fargate with encrypted CloudWatch logs

All modules pass Sentinel hard-fail and Wiz CICD checks when used correctly.
