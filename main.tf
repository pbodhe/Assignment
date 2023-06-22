resource "aws_sns_topic" "prometheus_alerts_topic" {
  name = "test-cluster-PrometheusAlerts"
  display_name = "AWS Prometheus Alert for test-cluster"
}

resource "aws_sns_topic_subscription" "prometheus_alerts_subscription" {
  topic_arn = aws_sns_topic.prometheus_alerts_topic.id
  endpoint = aws_lambda_function.prometheus_alerts_function.arn
  protocol = "lambda"
}

resource "aws_dynamodb_table" "eks_cluster_monitoring_table" {
  name = "eks_cluster_monitoring"
  billing_mode = "PAY_PER_REQUEST"
  attribute {
    name = "cluster_name"
    type = "S"
  }
  hash_key = "cluster_name"
  attribute {
    name = "alert_name"
    type = "S"
  }
  range_key = "alert_name"
}

resource "aws_lambda_permission" "prometheus_alerts_function_invoke_permission" {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.prometheus_alerts_function.arn
  principal = "sns.amazonaws.com"
  source_arn = aws_sns_topic.prometheus_alerts_topic.id
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "src/app.py"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "prometheus_alerts_function" {
  function_name = "prometheus-alerts-function"
  filename = "lambda_function_payload.zip"
  handler = "app.lambda_handler"
  role = aws_iam_role.prometheus_alerts_function_role.arn
  runtime = "python3.9"
  architectures = [
    "x86_64"
  ]
}

resource "aws_iam_role" "prometheus_alerts_function_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole"
        ]
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com"
          ]
        }
      }
    ]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
  inline_policy {
    name = "prometheus_alerts_function_role_policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
          {
            Action = [
              "dynamodb:*"
            ]
            Effect = "Allow"
            Resource = "*"
          }
        ]
    })
  }
}
