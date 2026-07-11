# Fraud Detection — Legacy Platform 1.0

**Source:** `app-teams/fraud-detection/main.tf`  
**Status:** NOT STARTED  
**Risk:** HIGH — Lambda with broad permissions, custom KMS, complex IAM  
**Owner:** Fraud Analytics Team

## Architecture

Lambda-based fraud scoring with S3 model storage, DynamoDB scores table, KMS encryption, and SNS alerts.

```hcl
resource "aws_lambda_function" "fraud_scorer" {
  function_name = "fraud-transaction-scorer"
  role          = aws_iam_role.fraud_lambda.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  environment {
    variables = {
      MODEL_BUCKET    = aws_s3_bucket.fraud_models.bucket
      DYNAMO_TABLE    = aws_dynamodb_table.fraud_scores.name
      KMS_KEY_ID      = aws_kms_key.fraud_data.id
      ALERT_TOPIC_ARN = aws_sns_topic.fraud_alerts.arn
    }
  }
}
```

## Inline IAM Violations (3 blocks) — lines 95-160

```hcl
resource "aws_iam_role" "fraud_lambda" {
  name = "fraud-lambda-role"

  # INLINE POLICY - broad S3 access
  inline_policy {
    name = "fraud-s3-full-access"
    policy = jsonencode({
      Statement = [{
        Effect   = "Allow"
        Action   = ["s3:*"]  # OVERLY BROAD
        Resource = [aws_s3_bucket.fraud_models.arn, "..."]
      }]
    })
  }

  inline_policy {
    name = "fraud-dynamodb-access"
    policy = jsonencode({
      Statement = [{
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan"]
        Resource = [aws_dynamodb_table.fraud_scores.arn]
      }]
    })
  }

  inline_policy {
    name = "fraud-supporting-services"
    policy = jsonencode({
      Statement = [{
        Effect   = "Allow"
        Action   = ["kms:*"]  # OVERLY BROAD - Wiz critical
        Resource = [aws_kms_key.fraud_data.arn]
      }]
    })
  }
}
```

## Migration Path

Replace `aws_iam_role.fraud_lambda` with `platform-modules/iam-role` and scope permissions per CCF least-privilege.
