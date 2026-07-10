# =============================================================================
# Platform Module: CCF-Compliant Networking
# Version: 2.0.3
# Description: VPC with mandatory flow logs, restricted egress, and standard
#              subnet layout. Passes all Sentinel and Wiz network checks.
# Maintainer: Platform Engineering
# =============================================================================

variable "team_name" {
  description = "Application team name for resource naming"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet CIDRs"
  type        = list(string)
}

variable "availability_zones" {
  description = "AZs for subnet placement"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

# --- VPC with mandatory flow logs ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.team_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets

  enable_nat_gateway = true
  single_nat_gateway = true

  # MANDATORY: VPC Flow Logs (CCF-NET-001)
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60

  tags = merge(var.tags, {
    Platform   = "2.0"
    Module     = "platform-modules/networking"
    Compliance = "CCF-NET-001"
  })
}

# --- Standard app security group with restricted egress ---
resource "aws_security_group" "app" {
  name        = "${var.team_name}-app-sg"
  description = "${var.team_name} application - Platform 2.0 compliant"
  vpc_id      = module.vpc.vpc_id

  # RESTRICTED EGRESS - only HTTPS and AWS service endpoints
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound (AWS APIs, ECR, etc.)"
  }

  # NO open egress (0.0.0.0/0 on all ports)
  # This is what differentiates 2.0 from legacy

  tags = merge(var.tags, {
    Platform = "2.0"
    Name     = "${var.team_name}-app-sg"
  })
}

# --- Outputs ---
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "app_security_group_id" {
  value = aws_security_group.app.id
}
