# Platform Module: CCF-Compliant Networking

**Source:** `platform-modules/networking/main.tf`  
**Version:** 2.0.3  
**CCF Control:** CCF-NET-001

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name    = "${var.team_name}-vpc"
  cidr    = var.vpc_cidr

  # MANDATORY: VPC Flow Logs (CCF-NET-001)
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60
}

resource "aws_security_group" "app" {
  name   = "${var.team_name}-app-sg"
  vpc_id = module.vpc.vpc_id

  # RESTRICTED EGRESS - only HTTPS
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound (AWS APIs, ECR, etc.)"
  }
  # NO open egress (0.0.0.0/0 on all ports)
}
```

Replaces legacy direct `aws_vpc` resources (e.g. `app-teams/wealth-management/main.tf`).
