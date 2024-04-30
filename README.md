# esf-terraform

You can find details on ESF in [Elastic Serverless Forwarder for AWS](https://www.elastic.co/guide/en/esf/current/aws-elastic-serverless-forwarder.html).

This repository contains all necessary resources to deploy ESF. 


## How to use

1. Define secrets and variables in `*.auto.tfvars` files. See `variables.tf` for the list of variables declared or read section [Inputs](#inputs). Example:
```terraform
# variables.auto.tfvars

lambda-name            = "my-esf-lambda"
release-version        = "lambda-v1.9.0" # See https://github.com/elastic/elastic-serverless-forwarder/tags
# config-file-bucket     = "arn:aws:s3:::my-esf-bucket" # Uncomment if s3 bucket pre-exists
aws_region             = "eu-central-1"
# config-file-local-path = "./config.yaml" # Uncomment if local config path is used
inputs = [
  {
    type = "cloudwatch-logs"
    id   = "<some_arn>"
    outputs = [
      {
        type = "elasticsearch"
        args = {
          elasticsearch_url  = "https://url.com"
          api_key            = "<some_api_key>"
          es_datastream_name = "logs-esf.cloudwatch-default"
        }
      }
    ]
  }
]
```

Please read section [Inputs configuration](#inputs-configuration) for more details on how to configure the inputs.
2. Execute `terraform init`
3. Execute `terraform apply`


## Inputs configuration

> Note: Read [Create and upload config.yaml to S3 bucket](https://www.elastic.co/guide/en/esf/current/aws-deploy-elastic-serverless-forwarder.html#sample-s3-config-file) if you need more details on how the inputs should be configured.

> Note: Read [Fields](https://www.elastic.co/guide/en/esf/current/aws-deploy-elastic-serverless-forwarder.html#s3-config-file-fields) to know which values are expected for each field input.

> Warning: If you use `s3-sqs` input type, you also need to configure `s3-buckets` variable.

When applying these configuration files, a `config.yaml` file will always be uploaded to an S3 bucket. This S3 bucket will be the one specified in `config-file-bucket`, or, if the value is left empty, a new S3 bucket will be created.

Following this, we will create the content for the `config.yaml` file. This file will be built based on:
- Variable `inputs`. This variable is not required.
- Local configuration file found in `config-file-local-path`. This variable is also not required.

If both variables are provided, both will be considered. Otherwise, just the one that was given. If none are provided, the `config.yaml` file will be:

```yaml
"inputs": []
```

It does not make sense to leave both empty.

You can see the following examples on the resulting `config.yaml` file.

#### Configure just the `inputs` variable
Configure the `inputs` variable as:

```terraform
inputs = [
  {
    type = "cloudwatch-logs"
    id   = "arn:aws:logs:eu-central-1:627286350134:log-group:coming-from-inputs-variable:*"
    outputs = [
      {
        type = "elasticsearch"
        args = {
          elasticsearch_url  = "<url>"
          api_key            = "<api key>"
          es_datastream_name = "logs-esf.cloudwatch-default"
        }
      }
    ]
  }
]
```

Do not configure the `config-file-bucket` variable, which will be left as ` ` (empty) since that is the default.


The `config.yaml` placed inside the bucket will be:

```yaml
"inputs":
  - "id": "arn:aws:logs:eu-central-1:627286350134:log-group:coming-from-inputs-variable:*"
    "outputs":
      - "args":
          "api_key": "<api key>"
          "elasticsearch_url": "<url>"
          "es_datastream_name": "logs-esf.cloudwatch-default"
        "type": "elasticsearch"
    "type": "cloudwatch-logs"
```

#### Configure just the `config-file-local-path` variable
Do not configure the `inputs` variable, which will be left as `[]` since that is the default.

Configure `config-file-local-path` variable:

```terraform
config-file-local-path = "./config.yaml"
```

And the local `config.yaml` file looks like:
```yaml
"inputs":
  - "id": "arn:aws:logs:eu-central-1:627286350134:log-group:coming-from-local-file:*"
    "outputs":
      - "args":
          "api_key": "<api key>"
          "elasticsearch_url": "<url>"
          "es_datastream_name": "logs-esf.cloudwatch-default"
        "type": "elasticsearch"
    "type": "cloudwatch-logs"
```

#### Configure both variables
Configure both `inputs` and `config-file-local-path` like in the previous examples.

The `config.yaml` placed inside the bucket will be:

```yaml
"inputs":
- "id": "arn:aws:logs:eu-central-1:627286350134:log-group:coming-from-inputs-variable:*"
  "outputs":
  - "args":
      "api_key": "<api key>"
      "elasticsearch_url": "<url>"
      "es_datastream_name": "logs-esf.cloudwatch-default"
    "type": "elasticsearch"
  "type": "cloudwatch-logs"
- "id": "arn:aws:logs:eu-central-1:627286350134:log-group:coming-from-local-file:*"
  "outputs":
  - "args":
      "api_key": "<api key>"
      "elasticsearch_url": "<url>"
      "es_datastream_name": "logs-esf.cloudwatch-default"
    "type": "elasticsearch"
  "type": "cloudwatch-logs"
```

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
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.14.0 |

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
| [aws_s3_bucket.esf-config-bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_object.config-file](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_sqs_queue.esf-continuing-queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.esf-continuing-queue-dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.esf-replay-queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.esf-replay-queue-dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_redrive_allow_policy.esf-continuing-queue-dlq-redrive-allow-policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_redrive_allow_policy) | resource |
| [aws_sqs_queue_redrive_allow_policy.esf-replay-queue-dlq-redrive-allow-policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_redrive_allow_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS Region | `string` | n/a | yes |
| <a name="input_config-file-bucket"></a> [config-file-bucket](#input\_config-file-bucket) | The ARN of the S3 bucket to place the config.yaml file. It should exist. Otherwise, if the variable is left empty, a new bucket will be created. | `string` | `""` | no |
| <a name="input_config-file-local-path"></a> [config-file-local-path](#input\_config-file-local-path) | Local path to the configuration file. Define this variable only if you want to specify the local configuration file. If none given, make sure to set inputs variable.<br>You can find instructions on how to set the configuration file in https://www.elastic.co/guide/en/esf/current/aws-deploy-elastic-serverless-forwarder.html#sample-s3-config-file. | `string` | `""` | no |
| <a name="input_continuing-queue"></a> [continuing-queue](#input\_continuing-queue) | Custom BatchSize and MaximumBatchingWindowInSeconds for the ESF SQS Continuing queue | <pre>object({<br>    batch_size                = optional(number, 10)<br>    batching_window_in_second = optional(number, 0)<br>  })</pre> | <pre>{<br>  "batch_size": 10,<br>  "batching_window_in_second": 0<br>}</pre> | no |
| <a name="input_inputs"></a> [inputs](#input\_inputs) | List of inputs to ESF. If none given, make sure to set config-file-local-path variable.<br>You can find instructions on the variables in https://www.elastic.co/guide/en/esf/current/aws-deploy-elastic-serverless-forwarder.html#s3-config-file-fields. | <pre>list(object({<br>    type = string<br>    id   = string<br>    outputs = list(object({<br>      type = string<br>      args = object({<br>        elasticsearch_url      = optional(string)<br>        logstash_url           = optional(string)<br>        cloud_id               = optional(string)<br>        api_key                = optional(string)<br>        username               = optional(string)<br>        password               = optional(string)<br>        es_datastream_name     = string<br>        batch_max_actions      = optional(number)<br>        batch_max_bytes        = optional(number)<br>        ssl_assert_fingerprint = optional(string)<br>        compression_level      = optional(string)<br>      })<br>    }))<br>  }))</pre> | `[]` | no |
| <a name="input_kms-keys"></a> [kms-keys](#input\_kms-keys) | List of KMS Keys ARNs to be used for decrypting AWS SSM Secrets, Kinesis Data Streams, SQS queue, or S3 buckets | `list(string)` | `[]` | no |
| <a name="input_lambda-name"></a> [lambda-name](#input\_lambda-name) | ESF Lambda function name | `string` | n/a | yes |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for ESF | `string` | `"INFO"` | no |
| <a name="input_release-version"></a> [release-version](#input\_release-version) | ESF release version. You can find the possible values in https://github.com/elastic/elastic-serverless-forwarder/tags. | `string` | n/a | yes |
| <a name="input_s3-buckets"></a> [s3-buckets](#input\_s3-buckets) | List of S3 bucket ARNs that are sources for the S3 SQS Event Notifications | `list(string)` | `[]` | no |
| <a name="input_ssm-secrets"></a> [ssm-secrets](#input\_ssm-secrets) | List of SSM Secrets ARNs used in the config.yml | `list(string)` | `[]` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | VPC to attach ESF to, identified by the list of its security group IDs and subnet IDs | <pre>object({<br>    security-groups = list(string)<br>    subnets         = list(string)<br>  })</pre> | <pre>{<br>  "security-groups": [],<br>  "subnets": []<br>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_s3-arn"></a> [s3-arn](#output\_s3-arn) | n/a |

<!-- END_TF_DOCS -->