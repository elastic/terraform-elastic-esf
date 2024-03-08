###### Elastic Serverless Forwarder
locals {
  attach_network_policy = (var.vpc != null ? true : false)

  s3-url-config-file = "s3://${split(":", var.config-file)[length(split(":", var.config-file))-1]}"

  kinesis-data-stream = (length(var.kinesis-data-stream) > 0 ? {
    kinesis-data-stream = { effect = "Allow", actions = [
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "kinesis:ListShards",
      "kinesis:ListStreams",
      "kinesis:SubscribeToShard"
    ], resources = [for kinesis-data-stream in var.kinesis-data-stream: kinesis-data-stream.arn] }
  } : {})

  sqs = (length(var.sqs) > 0 ? {
    sqs = { effect = "Allow", actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ], resources = [for sqs in var.sqs: sqs.arn] },
    s3-sqs = { effect = "Allow", actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ], resources = [for s3-sqs in var.s3-sqs: s3-sqs.arn] }
  } : {})

  ssm-secrets = (length(var.ssm-secrets) > 0 ? {
    ssm-secrets = { effect = "Allow", actions = ["secretsmanager:GetSecretValue"], resources = var.ssm-secrets }
  } : {})

  kms-keys = (length(var.kms-keys) > 0 ? {
    kms-keys = { effect = "Allow", actions = ["kms:Decrypt"], resources = var.kms-keys }
  } : {})

  s3-buckets = (length(var.s3-buckets) > 0 ? {
    s3-buckets-list_bucket = { effect = "Allow", actions = ["s3:ListBucket"], resources = var.s3-buckets },
    s3-buckets-get_object = { effect = "Allow", actions = ["s3:GetObject"], resources = [for arn in var.s3-buckets: "${arn}/*"] }
  } : {})

  ec2 = (length(var.cloudwatch-logs) > 0 ? {
    ec2 = { effect = "Allow", actions = ["ec2:DescribeRegions"], resources = ["*"] }} : {}
  )
}

data "external" "esf_lambda_loader" {
  program = ["${path.module}/esf-loader.sh"]

  query = {
    version = var.release-version
  }
}

module "esf-lambda-function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "6.0.0"

  function_name                  = var.lambda-name
  handler                        = "main_aws.lambda_handler"
  runtime                        = "python3.9"
  build_in_docker                = true
  architectures                  = ["x86_64"]
  docker_pip_cache               = true
  memory_size                    = 512
  timeout                        = 900
  docker_additional_options      = ["--platform", "linux/amd64"]
  source_path                    = data.external.esf_lambda_loader.result.package
  environment_variables = {
    S3_CONFIG_FILE : local.s3-url-config-file
    SQS_CONTINUE_URL : aws_sqs_queue.esf-continuing-queue.url
    SQS_REPLAY_URL : aws_sqs_queue.esf-replay-queue.url
    LOG_LEVEL : var.log_level
  }

  vpc_subnet_ids = var.vpc.subnets
  vpc_security_group_ids = var.vpc.security-groups
  attach_network_policy = local.attach_network_policy

  attach_policies = true
  number_of_policies = 1
  policies = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  attach_policy_statements = true

  policy_statements = merge(
    {
      config-file = {
        effect    = "Allow",
        actions   = ["s3:GetObject"],
        resources = [var.config-file]
      },
      internal-queues = {
        effect    = "Allow",
        actions   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
        resources = [aws_sqs_queue.esf-continuing-queue.arn, aws_sqs_queue.esf-replay-queue.arn]
      }
    },
    local.kinesis-data-stream,
    local.sqs,
    local.ssm-secrets,
    local.kms-keys,
    local.s3-buckets,
    local.ec2
  )

  depends_on = [data.external.esf_lambda_loader]

  use_existing_cloudwatch_log_group = false
}


resource "aws_lambda_event_source_mapping" "esf-event-source-mapping-kinesis-data-stream" {
  for_each = { for kinesis-data-stream in var.kinesis-data-stream: kinesis-data-stream.arn => kinesis-data-stream }
  event_source_arn                   = each.value.arn
  function_name                      = module.esf-lambda-function.lambda_function_arn
  batch_size                         = each.value.batch_size
  maximum_batching_window_in_seconds = each.value.batching_window_in_second
  parallelization_factor             = each.value.parallelization_factor
  starting_position                  = each.value.starting_position
  starting_position_timestamp        = each.value.starting_position_timestamp
  enabled                            = true
  depends_on                         = [module.esf-lambda-function]
}

resource "aws_lambda_event_source_mapping" "esf-event-source-mapping-sqs" {
  for_each = { for sqs in var.sqs: sqs.arn => sqs }
  event_source_arn                   = each.value.arn
  function_name                      = module.esf-lambda-function.lambda_function_arn
  batch_size                         = each.value.batch_size
  maximum_batching_window_in_seconds = each.value.batching_window_in_second
  enabled                            = true
  depends_on                         = [module.esf-lambda-function]
}

resource "aws_lambda_event_source_mapping" "esf-event-source-mapping-s3-sqs" {
  for_each = { for s3-sqs in var.s3-sqs: s3-sqs.arn => s3-sqs }
  event_source_arn                   = each.value.arn
  function_name                      = module.esf-lambda-function.lambda_function_arn
  batch_size                         = each.value.batch_size
  maximum_batching_window_in_seconds = each.value.batching_window_in_second
  enabled                            = true
  depends_on                         = [module.esf-lambda-function]
}

resource "aws_lambda_permission" "esf-cloudwatch-logs-invoke-function-permission" {
  for_each = { for cloudwatch-logs in var.cloudwatch-logs: cloudwatch-logs => cloudwatch-logs }
  action        = "lambda:InvokeFunction"
  function_name = module.esf-lambda-function.lambda_function_name
  principal     = "logs.${split(":", each.value)[3]}.amazonaws.com"
  source_arn    = each.value
}

resource "aws_cloudwatch_log_subscription_filter" "esf-cloudwatch-log-subscription-filter" {
  for_each = { for cloudwatch-logs in var.cloudwatch-logs: cloudwatch-logs => cloudwatch-logs }
  name            = split(":", each.value)[6]
  destination_arn = module.esf-lambda-function.lambda_function_arn
  filter_pattern  = ""
  log_group_name  = split(":", each.value)[6]
  depends_on = [aws_lambda_permission.esf-cloudwatch-logs-invoke-function-permission]
}

resource "aws_lambda_event_source_mapping" "esf-event-source-mapping-continuing-queue" {
  event_source_arn                   = aws_sqs_queue.esf-continuing-queue.arn
  function_name                      = module.esf-lambda-function.lambda_function_arn
  batch_size                         = var.continuing-queue.batch_size
  maximum_batching_window_in_seconds = var.continuing-queue.batching_window_in_second
}

resource "aws_sqs_queue" "esf-continuing-queue-dlq" {
  name                       = "${var.lambda-name}-continuing-queue-dlq"
  delay_seconds              = 0
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = 910
}

resource "aws_sqs_queue_redrive_allow_policy" "esf-continuing-queue-dlq-redrive-allow-policy" {
  queue_url = aws_sqs_queue.esf-continuing-queue-dlq.url

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.esf-continuing-queue.arn]
  })
}

resource "aws_sqs_queue" "esf-continuing-queue" {
  name                       = "${var.lambda-name}-continuing-queue"
  delay_seconds              = 0
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = 910
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.esf-continuing-queue-dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "esf-replay-queue-dlq" {
  name                       = "${var.lambda-name}-replay-queue-dlq"
  delay_seconds              = 0
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = 910
}

resource "aws_sqs_queue_redrive_allow_policy" "esf-replay-queue-dlq-redrive-allow-policy" {
  queue_url = aws_sqs_queue.esf-replay-queue-dlq.url

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.esf-replay-queue.arn]
  })
}

resource "aws_sqs_queue" "esf-replay-queue" {
  name                       = "${var.lambda-name}-replay-queue"
  delay_seconds              = 0
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = 910
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.esf-replay-queue-dlq.arn
    maxReceiveCount     = 3
  })
}
