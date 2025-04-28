terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "2.7.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

locals {
  prefix = "${var.user-name}-${var.project-name}"
}

# Bucket for storing images
resource "aws_s3_bucket" "this" {
  bucket = "${local.prefix}-bucket"
}

# DynamoDB table for storing image attributes
resource "aws_dynamodb_table" "this" {
  name         = "${local.prefix}-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "Image"

  attribute {
    name = "Image"
    type = "S"
  }
}

# AWS Lambda function
resource "aws_iam_role" "this" {
  name = "${local.prefix}-lambdarole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "this" {
  name        = "${local.prefix}-policy"
  description = "Policy for Lambda to access rekognition, s3, and dynamodb"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "rekognition:*",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = ["s3:GetObject"],
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.this.arn}/*"]
      },
      {
        Action   = ["s3:ListBucket"],
        Effect   = "Allow",
        Resource = ["${aws_s3_bucket.this.arn}"]
      },
      {
        Action = ["dynamodb:PutItem"],
        Effect   = "Allow"
        Resource = ["${aws_dynamodb_table.this.arn}"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

data "archive_file" "this" {
  type        = "zip"
  source_file = "../lambda/index.py"
  output_path = "../lambda_function_payload.zip"
}

resource "aws_lambda_function" "this" {
  filename         = "../lambda_function_payload.zip"
  source_code_hash = data.archive_file.this.output_base64sha256
  function_name    = "${local.prefix}-lambda"
  handler          = "index.handler"
  role             = aws_iam_role.this.arn
  runtime          = "python3.11"
  timeout          = 300
  memory_size      = 256

  environment {
    variables = {
      BUCKET = aws_s3_bucket.this.bucket
      TABLE  = aws_dynamodb_table.this.name
    }
  }
}

# trigger lambda whenever object is created in s3 bucket
resource "aws_s3_bucket_notification" "image_event_notification" {
  bucket = aws_s3_bucket.this.bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.this.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.this.arn
}