terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40.0"
    }
  }
  backend "s3" {
    bucket = "bucket-terraform-state-for-testing-jahp"
    key    = "ts_lambda/terraform.tfstate"
    region = "us-east-1"
  }
}

# Can be commented and terraform will use the region specified in your 
# local configuration (usually ~/.aws/config) 
provider "aws" {
  region = "us-east-1"
}

# S3 buckets are globally unique so two buckets names of two
# different AWS accounts can't be the same.
resource "aws_s3_bucket" "terraform_state" {
  bucket = "bucket-terraform-state-for-testing"

  # Uncomment if want to prevent accidental deletion of this S3 bucket
  # lifecycle {
  #   prevent_destroy = true
  # }
}

resource "aws_iam_role" "ts_lambda_role" {
  name = "ts_lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}


resource "aws_lambda_function" "ts_lambda" {
  filename      = "zips/lambda_function_${var.lambda_version}.zip"
  function_name = "ts_lambda"
  role          = aws_iam_role.ts_lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  memory_size   = 1024
  timeout       = 300
}

resource "aws_cloudwatch_log_group" "ts_lambda_loggroup" {
  name              = "/aws/lambda/${aws_lambda_function.ts_lambda.function_name}"
  retention_in_days = 3
}

data "aws_iam_policy_document" "ts_lambda_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      aws_cloudwatch_log_group.ts_lambda_loggroup.arn,
      "${aws_cloudwatch_log_group.ts_lambda_loggroup.arn}:*"
    ]
  }
}

resource "aws_iam_role_policy" "ts_lambda_role_policy" {
  policy = data.aws_iam_policy_document.ts_lambda_policy.json
  role   = aws_iam_role.ts_lambda_role.id
  name   = "tf_lambda-policy"
}

resource "aws_lambda_function_url" "ts_lambda_funtion_url" {
  function_name      = aws_lambda_function.ts_lambda.id
  authorization_type = "NONE"
  cors {
    allow_origins = ["*"]
  }
}
