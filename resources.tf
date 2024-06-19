terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  #shared_credentials_files = ["~/.aws/credentials"]
  #profile                  = "default"
}

resource "aws_s3_bucket" "mys3" {
  bucket = "rigas32"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_policy" "allow_public_access" {
  bucket = aws_s3_bucket.mys3.id
  policy = data.aws_iam_policy_document.allow_pub_access.json
}

data "aws_iam_policy_document" "allow_pub_access" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject"
    ]

    effect = "Allow"

    resources = [
      aws_s3_bucket.mys3.arn,
      "${aws_s3_bucket.mys3.arn}/*"
    ]
  }
}

resource "aws_s3_bucket_ownership_controls" "ownership" {
  bucket = aws_s3_bucket.mys3.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "aclbucket" {
  bucket = aws_s3_bucket.mys3.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "rigaacl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.ownership,
    aws_s3_bucket_public_access_block.aclbucket,
  ]

  bucket = aws_s3_bucket.mys3.id
  acl    = "public-read"
}

# Lambda function
resource "aws_lambda_function" "my_lambda" {
  function_name    = "myqrcodegenerator"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  memory_size      = 128
  timeout          = 10
  source_code_hash = filebase64sha256("${path.module}/qr.zip")
  s3_bucket        = aws_s3_bucket.mys3.id
  s3_key           = aws_s3_bucket_object.mylambda_zip.key

  # Use an existing IAM role
  role = "arn:aws:iam::975049925614:role/service-role/python2-role-6z6ifmb5" # Change this to your existing IAM role ARN

  environment {
    variables = {
      key = "value"
    }
  }
}

resource "aws_s3_bucket_object" "mylambda_zip" {
  bucket       = aws_s3_bucket.mys3.id
  key          = "qr.zip"
  source       = "${path.module}/qr.zip"
  etag         = filemd5("${path.module}/qr.zip")
  content_type = "application/zip"
  #   acl          = "public-read"
}

resource "aws_api_gateway_rest_api" "api" {
  name        = "QRAPI"
  description = "API for QR Code Generation"
}

resource "aws_api_gateway_resource" "qr_code_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "qr-code"
}

resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.qr_code_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.qr_code_resource.id
  http_method             = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.my_lambda.invoke_arn
}

resource "aws_lambda_permission" "apigateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:us-east-1:975049925614:${aws_api_gateway_rest_api.api.id}/*/*"
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.qr_code_resource.id
  http_method = aws_api_gateway_method.post_method.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

resource "aws_api_gateway_integration_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.qr_code_resource.id
  http_method = aws_api_gateway_method.post_method.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  response_templates = {
    "application/json" = "#set($origin = $input.params().header.get('Origin'))\n#if($origin)\n  #set($context.responseOverride.header.Access-Control-Allow-Origin = $origin)\n#end\n{}"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'",
  }
  depends_on = [aws_api_gateway_integration.lambda_integration]
}

resource "aws_api_gateway_method" "options_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.qr_code_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}
resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.qr_code_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  depends_on = [aws_api_gateway_method.options_method]
}
resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.qr_code_resource.id
  http_method             = aws_api_gateway_method.options_method.http_method
  type                    = "MOCK"
  depends_on              = [aws_api_gateway_method.options_method]
  integration_http_method = "POST"
}
resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.qr_code_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [aws_api_gateway_method_response.options_200]
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [aws_api_gateway_integration.lambda_integration]

  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "stage1"
}

output "api_url" {
  value = aws_api_gateway_deployment.deployment.invoke_url
}


