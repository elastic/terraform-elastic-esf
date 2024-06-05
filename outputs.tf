/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License
 * 2.0; you may not use this file except in compliance with the Elastic License
 * 2.0.
 */

output "config-bucket-name" {
  value       = local.config-bucket-name
  description = "Name of the bucket with the config.yaml and zip dependencies file."
}

output "esf-continuing-queue-dlq" {
  value       = aws_sqs_queue.esf-continuing-queue-dlq.name
  description = "Name of the Dead Letter Queue for the ESF continuing queue."
}

output "esf-continuing-queue" {
  value       = aws_sqs_queue.esf-continuing-queue.name
  description = "Name of the ESF continuing queue."
}

output "esf-replay-queue-dlq" {
  value       = aws_sqs_queue.esf-replay-queue-dlq.name
  description = "Name of the Dead Letter Queue for the ESF replay queue."
}

output "esf-replay-queue" {
  value       = aws_sqs_queue.esf-replay-queue.name
  description = "Name of the ESF replay queue."
}


