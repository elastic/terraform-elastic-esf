variable "lambda-name" {
  description = "ESF Lambda function name"
  type        = string
}

variable "release-version" {
  description = "ESF release version"
  type = string
}

variable "config-file" {
  description = "ARN of to the location of config.yaml for ESF in S3"
  type = string
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

variable "cloudwatch-logs" {
  description = "List of Cloudwatch Logs to add a Subscription Filters for to ESF"
  type = list(object({
    arn = string
  }))
  default = [{
    arn = ""
  }]
}

variable "kinesis-data-stream" {
  description = "List of Kinesis Data Stream to add an Event Source for to ESF"
  type = list(object({
    arn = string
    batch_size = optional(number, 10)
    starting_position = optional(string, "TRIM_HORIZON")
    starting_position_timestamp = optional(number)
    batching_window_in_second = optional(number, 0)
    parallelization_factor = optional(number, 1)
  }))
  default = [{
    arn = ""
    batch_size = 10
    starting_position = "TRIM_HORIZON"
    starting_position_timestamp = null
    batching_window_in_second = 0
    parallelization_factor = 1
  }]
}

variable "sqs" {
  description = "List of Direct SQS queues to add an Event Source for to ESF"
  type = list(object({
    arn = string
    batch_size = optional(number, 10)
    batching_window_in_second = optional(number, 0)
  }))
  default = [{
    arn = ""
    batch_size = 10
    batching_window_in_second = 0
  }]
}

variable "s3-sqs" {
  description = "List of S3 SQS Event Notifications queues to add an Event Source for to ESF"
  type = list(object({
    arn = string
    batch_size = optional(number, 10)
    batching_window_in_second = optional(number, 0)
  }))
  default = [{
    arn = ""
    batch_size = 10
    batching_window_in_second = 0
  }]
}

variable "kms-keys" {
  description = "List of KMS Keys ARNs to be used for decrypting AWS SSM Secrets, Kinesis Data Streams, SQS queue, or S3 buckets"
  type = list(string)
  default = []
}

variable "ssm-secrets" {
  description = "List of SSM Secrets ARNs used in the config.yml"
  type = list(string)
  default = []
}

variable "s3-buckets" {
  description = "List of S3 bucket ARNs that are sources for the S3 SQS Event Notifications"
  type = list(string)
  default = []
}

variable "vpc" {
  description = "VPC to attach ESF to, identified by the list of its security group IDs and subnet IDs"
  type = object({
    security-groups = list(string)
    subnets = list(string)
  })
  default = {
    security-groups = []
    subnets = []
  }
}

variable "continuing-queue" {
  description = "Custom BatchSize and MaximumBatchingWindowInSeconds for the ESF SQS Continuing queue"
  type = object({
    batch_size = optional(number, 10)
    batching_window_in_second = optional(number, 0)
  })
  default = {
    batch_size = 10
    batching_window_in_second = 0
  }
}