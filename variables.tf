/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License
 * 2.0; you may not use this file except in compliance with the Elastic License
 * 2.0.
 */

variable "lambda-name" {
  description = "ESF Lambda function name"
  type        = string
}

variable "release-version" {
  description = "ESF release version. You can find the possible values in https://github.com/elastic/elastic-serverless-forwarder/tags."
  type        = string

  validation {
    condition     = can(regex("^lambda-v[0-9]+\\.[0-9]+\\.[0-9]+$", var.release-version))
    error_message = "The release-version must match the format lambda-v<major>.<minor>.<patch>. For example, lambda-v1.20.0."
  }
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "log_level" {
  description = "Log level for ESF"
  type        = string
  default     = "INFO"
}

variable "config-file-bucket" {
  description = <<EOT
The name of the S3 bucket to place the config.yaml file and the dependencies zip.
If the variable is left empty, a new bucket will be created. Otherwise, the bucket needs to preexist.
EOT
  type        = string
  default     = ""
}

variable "config-file-local-path" {
  description = <<EOT
Local path to the configuration file. Define this variable only if you want to specify the local configuration file. If none given, make sure to set inputs variable.
You can find instructions on how to set the configuration file in https://www.elastic.co/guide/en/esf/current/aws-deploy-elastic-serverless-forwarder.html#sample-s3-config-file.
EOT
  type        = string
  default     = ""
}

variable "inputs" {
  description = <<EOT
List of inputs to ESF. If none given, make sure to set config-file-local-path variable.
You can find instructions on the variables in https://www.elastic.co/guide/en/esf/current/aws-deploy-elastic-serverless-forwarder.html#s3-config-file-fields.
EOT
  type = list(object({
    type = string
    id   = string
    outputs = list(object({
      type = string
      args = object({
        elasticsearch_url      = optional(string)
        logstash_url           = optional(string)
        cloud_id               = optional(string)
        api_key                = optional(string)
        username               = optional(string)
        password               = optional(string)
        es_datastream_name     = string
        batch_max_actions      = optional(number)
        batch_max_bytes        = optional(number)
        ssl_assert_fingerprint = optional(string)
        compression_level      = optional(string)
      })
    }))
  }))
  default = []

  validation {
    condition = alltrue([
      for input in var.inputs :
      contains(["cloudwatch-logs", "kinesis-data-stream", "sqs", "s3-sqs"], input.type)
    ])
    error_message = "The type of trigger input needs to be one of: cloudwatch-logs, kinesis-data-stream, sqs or s3-sqs."
  }

  validation {
    condition = alltrue([
      for input in var.inputs : alltrue([
        for output in input.outputs : alltrue([
          contains(["elasticsearch", "logstash"], output.type)
        ])
      ])
    ])
    error_message = "The type of output can only be elasticsearch or logstash."
  }

  validation {
    condition = alltrue([
      for input in var.inputs : alltrue([
        for output in input.outputs : alltrue([
          output.type == "elasticsearch" ?
          (output.args.elasticsearch_url == null && output.args.cloud_id == null ? false : true) :
          (output.args.logstash_url == null ? false : true)
        ])
      ])
    ])
    error_message = "All elasticsearch outputs must contain elasticsearch_url or cloud_id. All logstash outputs must contain logstash_url."
  }

  validation {
    condition = alltrue([
      for input in var.inputs : alltrue([
        for output in input.outputs : alltrue([
          output.type == "elasticsearch" ?
          ((output.args.username == null || output.args.password == null) && output.args.api_key == null ? false : true) :
          (output.args.username == null || output.args.password == null ? false : true)
        ])
      ])
    ])
    error_message = "All elasticsearch outputs must contain api key or username and password. All logstash outputs must contain username and password."
  }
}

variable "kms-keys" {
  description = "List of KMS Keys ARNs to be used for decrypting AWS SSM Secrets, Kinesis Data Streams, SQS queue, or S3 buckets"
  type        = list(string)
  default     = []
}

variable "ssm-secrets" {
  description = "List of SSM Secrets ARNs used in the config.yml"
  type        = list(string)
  default     = []
}

variable "s3-buckets" {
  description = "List of S3 bucket ARNs that are sources for the S3 SQS Event Notifications"
  type        = list(string)
  default     = []
}

variable "vpc" {
  description = "VPC to attach ESF to, identified by the list of its security group IDs and subnet IDs"
  type = object({
    security-groups = list(string)
    subnets         = list(string)
  })
  default = {
    security-groups = []
    subnets         = []
  }
}

variable "continuing-queue" {
  description = "Custom BatchSize and MaximumBatchingWindowInSeconds for the ESF SQS Continuing queue"
  type = object({
    batch_size                = optional(number, 10)
    batching_window_in_second = optional(number, 0)
  })
  default = {
    batch_size                = 10
    batching_window_in_second = 0
  }
}

variable "lambda-timeout" {
  description = "The amount of time your Lambda Function has to run in seconds."
  type        = number
  default     = 900
}