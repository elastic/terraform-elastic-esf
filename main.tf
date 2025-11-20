/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License
 * 2.0; you may not use this file except in compliance with the Elastic License
 * 2.0.
 */

terraform {
  required_version = ">= 1.12.0"
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3.5"
    }
    local = {
      source  = "hashicorp/local"
      version = "~>2.6.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.20"
    }
  }
}

provider "aws" {
  region = var.aws_region
}





