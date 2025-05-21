/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License
 * 2.0; you may not use this file except in compliance with the Elastic License
 * 2.0.
 */

###### Elastic Serverless Forwarder
locals {
  dependencies-bucket-url = "http://esf-dependencies.s3.amazonaws.com"
  dependencies-file       = "${var.release-version}.zip"

  attach_network_policy = (var.vpc != null ? true : false)

  config-bucket-name = var.config-file-bucket == "" ? (
    "${var.lambda-name}-config-bucket"
    ) : (
    split(":", var.config-file-bucket)[length(split(":", var.config-file-bucket)) - 1]
  )
  content-config-file = var.config-file-local-path == "" ? {} : yamldecode(file("${var.config-file-local-path}"))

  # There are null entries in the inputs if not all fields were filled.
  # This will later cause errors in the code if the entries are not expected.
  # We need to make sure we will not pass these fields to the file when we make them part of the YAML content.
  inputs-without-nulls = [
    for input in var.inputs :
    {
      id : input.id,
      type : input.type,
      outputs : [
        for output in input.outputs : {
          type : output.type
          args : {
            for key, arg in output.args :
            key => arg if arg != null
          }
        }
      ]
    }
  ]

  # Join all inputs together: the ones coming from the variables, and the ones coming from the local config.yaml file.
  all-inputs = {
    inputs : concat(
      local.inputs-without-nulls,
      local.content-config-file == {} ? [] : local.content-config-file["inputs"]
    )
  }

  cloudwatch-logs-arns = compact(flatten([
    [for input in local.all-inputs.inputs : (
      input["type"] == "cloudwatch-logs" ? input["id"] : ""
      )
    ]
  ]))

  kinesis-data-streams-arns = compact(flatten([
    [for input in local.all-inputs.inputs : (
      input["type"] == "kinesis-data-stream" ? input["id"] : ""
      )
    ]
  ]))

  kinesis-data-stream = (length(local.kinesis-data-streams-arns) > 0 ? {
    kinesis-data-stream = { effect = "Allow", actions = [
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "kinesis:ListShards",
      "kinesis:ListStreams",
      "kinesis:SubscribeToShard"
    ], resources = local.kinesis-data-streams-arns }
  } : {})

  sqs-arns = compact(flatten([
    [for input in local.all-inputs.inputs : (
      input["type"] == "sqs" ? input["id"] : ""
      )
    ]
  ]))

  sqs = (length(local.sqs-arns) > 0 ? {
    sqs = { effect = "Allow", actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ], resources = local.sqs-arns }
  } : {})

  s3-sqs-arns = compact(flatten([
    [for input in local.all-inputs.inputs : (
      input["type"] == "s3-sqs" ? input["id"] : ""
      )
    ]
  ]))

  s3-sqs = (length(local.s3-sqs-arns) > 0 ? {
    s3-sqs = { effect = "Allow", actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ], resources = local.s3-sqs-arns }
  } : {})

  ssm-secrets = (length(var.ssm-secrets) > 0 ? {
    ssm-secrets = { effect = "Allow", actions = ["secretsmanager:GetSecretValue"], resources = var.ssm-secrets }
  } : {})

  kms-keys = (length(var.kms-keys) > 0 ? {
    kms-keys = { effect = "Allow", actions = ["kms:Decrypt"], resources = var.kms-keys }
  } : {})

  s3-buckets = (length(var.s3-buckets) > 0 ? {
    s3-buckets-list_bucket = { effect = "Allow", actions = ["s3:ListBucket"], resources = var.s3-buckets },
    s3-buckets-get_object  = { effect = "Allow", actions = ["s3:GetObject"], resources = [for arn in var.s3-buckets : "${arn}/*"] }
  } : {})

  # Unpack release-version (e.g., `lambda-v1.20.0`) into major, minor, patch
  release-version-unpacked = split(".", replace(var.release-version, "lambda-v", ""))

  release-version-parts = {
    major = tonumber(local.release-version-unpacked[0])
    minor = tonumber(local.release-version-unpacked[1])
    patch = tonumber(local.release-version-unpacked[2])
  }
}

check "esf-release" {
  assert {
    condition = (
      (local.release-version-parts.major > 1) ||
      (local.release-version-parts.major == 1 && local.release-version-parts.minor > 7) ||
      (local.release-version-parts.major == 1 && local.release-version-parts.minor == 7 && local.release-version-parts.patch >= 2)
    )
    # Why version 1.7.2? Because before that version, ESF was listing the regions and required the `ec2:DescribeRegions` permission.
    # See https://github.com/elastic/elastic-serverless-forwarder/pull/811
    error_message = "Release version ${var.release-version} is not supported. Please use a version >= 1.7.2"
  }
}


resource "aws_s3_bucket" "esf-config-bucket" {
  count = var.config-file-bucket == "" ? 1 : 0

  bucket        = local.config-bucket-name
  force_destroy = true
}

resource "aws_s3_object" "config-file" {
  bucket  = local.config-bucket-name
  key     = "config.yaml"
  content = yamlencode(local.all-inputs)

  depends_on = [aws_s3_bucket.esf-config-bucket]
}

resource "terraform_data" "curl-dependencies-zip" {
  provisioner "local-exec" {
    command = "curl -L -O ${local.dependencies-bucket-url}/${local.dependencies-file}"
  }
}

resource "aws_s3_object" "dependencies-file" {
  bucket = local.config-bucket-name
  key    = local.dependencies-file
  source = local.dependencies-file

  depends_on = [aws_s3_bucket.esf-config-bucket, terraform_data.curl-dependencies-zip]
}


module "esf-lambda-function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "6.0.0"

  function_name = var.lambda-name
  handler       = "main_aws.lambda_handler"
  runtime       = "python3.9"
  architectures = ["x86_64"]
  timeout       = var.lambda-timeout

  create_package = false
  s3_existing_package = {
    bucket = local.config-bucket-name
    key    = local.dependencies-file
  }

  environment_variables = {
    S3_CONFIG_FILE : "s3://${local.config-bucket-name}/config.yaml"
    SQS_CONTINUE_URL : aws_sqs_queue.esf-continuing-queue.url
    SQS_REPLAY_URL : aws_sqs_queue.esf-replay-queue.url
    LOG_LEVEL : var.log_level
  }

  vpc_subnet_ids         = var.vpc.subnets
  vpc_security_group_ids = var.vpc.security-groups
  attach_network_policy  = local.attach_network_policy

  attach_policies    = true
  number_of_policies = 1
  policies           = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  attach_policy_statements = true

  policy_statements = merge(
    {
      config-file = {
        effect  = "Allow",
        actions = ["s3:GetObject"],
        resources = [
          "arn:aws:s3:::${local.config-bucket-name}/config.yaml",
          "arn:aws:s3:::${local.config-bucket-name}/${local.dependencies-file}"
        ]
      },
      internal-queues = {
        effect    = "Allow",
        actions   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
        resources = [aws_sqs_queue.esf-continuing-queue.arn, aws_sqs_queue.esf-replay-queue.arn]
      }
    },
    local.kinesis-data-stream,
    local.s3-sqs,
    local.sqs,
    local.ssm-secrets,
    local.kms-keys,
    local.s3-buckets
  )

  use_existing_cloudwatch_log_group = false

  depends_on = [aws_s3_object.config-file, aws_s3_object.dependencies-file]
}

resource "aws_lambda_event_source_mapping" "esf-event-source-mapping-kinesis-data-stream" {
  for_each          = toset(local.kinesis-data-streams-arns)
  event_source_arn  = each.value
  function_name     = module.esf-lambda-function.lambda_function_arn
  starting_position = "TRIM_HORIZON"
  enabled           = true

  # We should wait for the update of the config.yaml
  depends_on = [module.esf-lambda-function, aws_s3_object.config-file]
}

resource "aws_lambda_event_source_mapping" "esf-event-source-mapping-sqs" {
  for_each         = toset(local.sqs-arns)
  event_source_arn = each.value
  function_name    = module.esf-lambda-function.lambda_function_arn
  enabled          = true

  # We should wait for the update of the config.yaml
  depends_on = [module.esf-lambda-function, aws_s3_object.config-file]
}

resource "aws_lambda_event_source_mapping" "esf-event-source-mapping-s3-sqs" {
  for_each         = toset(local.s3-sqs-arns)
  event_source_arn = each.value
  function_name    = module.esf-lambda-function.lambda_function_arn
  enabled          = true

  # We should wait for the update of the config.yaml
  depends_on = [module.esf-lambda-function, aws_s3_object.config-file]
}

resource "aws_lambda_permission" "esf-cloudwatch-logs-invoke-function-permission" {
  for_each      = toset(local.cloudwatch-logs-arns)
  action        = "lambda:InvokeFunction"
  function_name = module.esf-lambda-function.lambda_function_name
  principal     = "logs.${split(":", each.value)[3]}.amazonaws.com"
  source_arn    = each.value
}

resource "aws_cloudwatch_log_subscription_filter" "esf-cloudwatch-log-subscription-filter" {
  for_each        = toset(local.cloudwatch-logs-arns)
  name            = split(":", each.value)[6]
  destination_arn = module.esf-lambda-function.lambda_function_arn
  filter_pattern  = ""
  log_group_name  = split(":", each.value)[6]

  # We should wait for the update of the config.yaml
  depends_on = [aws_lambda_permission.esf-cloudwatch-logs-invoke-function-permission, aws_s3_object.config-file]
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