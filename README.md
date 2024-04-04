# esf-terraform

This repository contains sample Terraform code designed to automate the provisioning of AWS resources necessary for deploying of Elastic Serverless Forwarder (ESF)

## Prerequisites

Since this module executes a script ensure your machine has the following software available:

* curl
* tar

## How to use

* Define secrets and variables in `*.auto.tfvars` files (See `variables.tf` for the list of variables declared)
* Execute `terraform init`
* Execute `terraform apply`

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.6 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.14.0 |
| <a name="requirement_external"></a> [external](#requirement\_external) | ~> 2.3.1 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.14.0 |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_esf-lambda-function"></a> [esf-lambda-function](#module\_esf-lambda-function) | terraform-aws-modules/lambda/aws | 6.0.0 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_subscription_filter.esf-cloudwatch-log-subscription-filter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_subscription_filter) | resource |
| [aws_lambda_event_source_mapping.esf-event-source-mapping-continuing-queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_event_source_mapping.esf-event-source-mapping-kinesis-data-stream](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_event_source_mapping.esf-event-source-mapping-s3-sqs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_event_source_mapping.esf-event-source-mapping-sqs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_permission.esf-cloudwatch-logs-invoke-function-permission](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_sqs_queue.esf-continuing-queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.esf-continuing-queue-dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.esf-replay-queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.esf-replay-queue-dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_redrive_allow_policy.esf-continuing-queue-dlq-redrive-allow-policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_redrive_allow_policy) | resource |
| [aws_sqs_queue_redrive_allow_policy.esf-replay-queue-dlq-redrive-allow-policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_redrive_allow_policy) | resource |
| [null_resource.esf-download-source-zip](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS Region | `string` | n/a | yes |
| <a name="input_cloudwatch-logs"></a> [cloudwatch-logs](#input\_cloudwatch-logs) | List of Cloudwatch log group ARNs to add a Subscription Filters for to ESF | <pre>list(object({<br>    arn = string<br>  }))</pre> | <pre>[<br>  {<br>    "arn": ""<br>  }<br>]</pre> | no |
| <a name="input_config-file-bucket"></a> [config-file-bucket](#input\_config-file-bucket) | The ARN of the S3 bucket containing config.yaml file | `string` | n/a | yes |
| <a name="input_continuing-queue"></a> [continuing-queue](#input\_continuing-queue) | Custom BatchSize and MaximumBatchingWindowInSeconds for the ESF SQS Continuing queue | <pre>object({<br>    batch_size                = optional(number, 10)<br>    batching_window_in_second = optional(number, 0)<br>  })</pre> | <pre>{<br>  "batch_size": 10,<br>  "batching_window_in_second": 0<br>}</pre> | no |
| <a name="input_kinesis-data-stream"></a> [kinesis-data-stream](#input\_kinesis-data-stream) | List of Kinesis Data Stream to add an Event Source for to ESF | <pre>list(object({<br>    arn                         = string<br>    batch_size                  = optional(number, 10)<br>    starting_position           = optional(string, "TRIM_HORIZON")<br>    starting_position_timestamp = optional(number)<br>    batching_window_in_second   = optional(number, 0)<br>    parallelization_factor      = optional(number, 1)<br>  }))</pre> | <pre>[<br>  {<br>    "arn": "",<br>    "batch_size": 10,<br>    "batching_window_in_second": 0,<br>    "parallelization_factor": 1,<br>    "starting_position": "TRIM_HORIZON",<br>    "starting_position_timestamp": null<br>  }<br>]</pre> | no |
| <a name="input_kms-keys"></a> [kms-keys](#input\_kms-keys) | List of KMS Keys ARNs to be used for decrypting AWS SSM Secrets, Kinesis Data Streams, SQS queue, or S3 buckets | `list(string)` | `[]` | no |
| <a name="input_lambda-name"></a> [lambda-name](#input\_lambda-name) | ESF Lambda function name | `string` | n/a | yes |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for ESF | `string` | `"INFO"` | no |
| <a name="input_release-version"></a> [release-version](#input\_release-version) | ESF release version | `string` | n/a | yes |
| <a name="input_s3-buckets"></a> [s3-buckets](#input\_s3-buckets) | List of S3 bucket ARNs that are sources for the S3 SQS Event Notifications | `list(string)` | `[]` | no |
| <a name="input_s3-sqs"></a> [s3-sqs](#input\_s3-sqs) | List of S3 SQS Event Notifications queues to add an Event Source for to ESF | <pre>list(object({<br>    arn                       = string<br>    batch_size                = optional(number, 10)<br>    batching_window_in_second = optional(number, 0)<br>  }))</pre> | <pre>[<br>  {<br>    "arn": "",<br>    "batch_size": 10,<br>    "batching_window_in_second": 0<br>  }<br>]</pre> | no |
| <a name="input_sqs"></a> [sqs](#input\_sqs) | List of Direct SQS queues to add an Event Source for to ESF | <pre>list(object({<br>    arn                       = string<br>    batch_size                = optional(number, 10)<br>    batching_window_in_second = optional(number, 0)<br>  }))</pre> | <pre>[<br>  {<br>    "arn": "",<br>    "batch_size": 10,<br>    "batching_window_in_second": 0<br>  }<br>]</pre> | no |
| <a name="input_ssm-secrets"></a> [ssm-secrets](#input\_ssm-secrets) | List of SSM Secrets ARNs used in the config.yml | `list(string)` | `[]` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | VPC to attach ESF to, identified by the list of its security group IDs and subnet IDs | <pre>object({<br>    security-groups = list(string)<br>    subnets         = list(string)<br>  })</pre> | <pre>{<br>  "security-groups": [],<br>  "subnets": []<br>}</pre> | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->