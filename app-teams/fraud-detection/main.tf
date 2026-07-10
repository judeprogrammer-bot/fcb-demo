# =============================================================================
# App Team: Fraud Detection
# Platform: 1.0 (LEGACY - NOT MIGRATED)
# Risk: HIGH - Lambda with broad permissions, custom KMS, complex IAM
# Owner: Fraud Analytics Team
# Last modified: 2025-01-22
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.67"
    }
  }
  backend "s3" {
    bucket         = "fcb-legacy-tfstate"
    key            = "fraud-detection/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks-legacy"
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- LAMBDA FUNCTIONS ---

resource "aws_lambda_function" "fraud_scorer" {
  function_name = "fraud-transaction-scorer"
  role          = aws_iam_role.fraud_lambda.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 512

  filename         = "fraud_scorer.zip"
  source_code_hash = filebase64sha256("fraud_scorer.zip")

  environment {
    variables = {
      MODEL_BUCKET    = aws_s3_bucket.fraud_models.bucket
      DYNAMO_TABLE    = aws_dynamodb_table.fraud_scores.name
      KMS_KEY_ID      = aws_kms_key.fraud_data.id
      ALERT_TOPIC_ARN = aws_sns_topic.fraud_alerts.arn
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.fraud_private_a.id, aws_subnet.fraud_private_b.id]
    security_group_ids = [aws_security_group.fraud_lambda.id]
  }

  tags = { Team = "fraud-detection" }
}

resource "aws_lambda_function" "fraud_aggregator" {
  function_name = "fraud-daily-aggregator"
  role          = aws_iam_role.fraud_lambda.arn
  handler       = "aggregator.handler"
  runtime       = "python3.11"
  timeout       = 900
  memory_size   = 1024

  filename         = "fraud_aggregator.zip"
  source_code_hash = filebase64sha256("fraud_aggregator.zip")

  environment {
    variables = {
      SOURCE_TABLE = aws_dynamodb_table.fraud_scores.name
      DEST_BUCKET  = aws_s3_bucket.fraud_reports.bucket
    }
  }

  tags = { Team = "fraud-detection" }
}

# --- IAM (LEGACY - OVERLY BROAD, MULTIPLE INLINE POLICIES) ---

resource "aws_iam_role" "fraud_lambda" {
  name = "fraud-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  # INLINE POLICY - broad S3 access across multiple buckets
  inline_policy {
    name = "fraud-s3-full-access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = ["s3:*"]  # OVERLY BROAD - should be scoped
        Resource = [
          aws_s3_bucket.fraud_models.arn,
          "${aws_s3_bucket.fraud_models.arn}/*",
          aws_s3_bucket.fraud_reports.arn,
          "${aws_s3_bucket.fraud_reports.arn}/*"
        ]
      }]
    })
  }

  # INLINE POLICY - DynamoDB access
  inline_policy {
    name = "fraud-dynamodb-access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          aws_dynamodb_table.fraud_scores.arn,
          "${aws_dynamodb_table.fraud_scores.arn}/index/*"
        ]
      }]
    })
  }

  # INLINE POLICY - KMS + SNS + CloudWatch
  inline_policy {
    name = "fraud-supporting-services"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["kms:*"]  # OVERLY BROAD - Wiz critical
          Resource = [aws_kms_key.fraud_data.arn]
        },
        {
          Effect   = "Allow"
          Action   = ["sns:Publish"]
          Resource = [aws_sns_topic.fraud_alerts.arn]
        },
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = ["arn:aws:logs:*:*:*"]
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:CreateNetworkInterface",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DeleteNetworkInterface"
          ]
          Resource = ["*"]
        }
      ]
    })
  }

  tags = { Team = "fraud-detection" }
}

# --- NETWORKING ---

resource "aws_vpc" "fraud" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "fraud-detection-vpc", Team = "fraud-detection" }
}

resource "aws_subnet" "fraud_private_a" {
  vpc_id            = aws_vpc.fraud.id
  cidr_block        = "10.2.1.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "fraud-private-a" }
}

resource "aws_subnet" "fraud_private_b" {
  vpc_id            = aws_vpc.fraud.id
  cidr_block        = "10.2.2.0/24"
  availability_zone = "us-east-1b"
  tags = { Name = "fraud-private-b" }
}

resource "aws_security_group" "fraud_lambda" {
  name        = "fraud-lambda-sg"
  description = "Fraud detection Lambda functions"
  vpc_id      = aws_vpc.fraud.id

  # No ingress needed for Lambda

  # OPEN EGRESS
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "fraud-lambda-sg", Team = "fraud-detection" }
}

# --- DATA STORES ---

resource "aws_dynamodb_table" "fraud_scores" {
  name         = "fraud-transaction-scores"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "transaction_id"
  range_key    = "timestamp"

  attribute {
    name = "transaction_id"
    type = "S"
  }
  attribute {
    name = "timestamp"
    type = "N"
  }
  attribute {
    name = "account_id"
    type = "S"
  }

  global_secondary_index {
    name            = "account-index"
    hash_key        = "account_id"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  point_in_time_recovery { enabled = true }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.fraud_data.arn
  }

  tags = { Team = "fraud-detection" }
}

resource "aws_s3_bucket" "fraud_models" {
  bucket = "fcb-fraud-ml-models-prod"
  tags   = { Team = "fraud-detection" }
}

resource "aws_s3_bucket" "fraud_reports" {
  bucket = "fcb-fraud-daily-reports-prod"
  tags   = { Team = "fraud-detection" }
}

# MISSING: public access blocks on both buckets

resource "aws_kms_key" "fraud_data" {
  description             = "Fraud detection data encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = { Team = "fraud-detection" }
}

resource "aws_sns_topic" "fraud_alerts" {
  name = "fraud-high-risk-alerts"
  # MISSING: KMS encryption for SNS topic
  tags = { Team = "fraud-detection" }
}
