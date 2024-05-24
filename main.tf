
terraform {
  required_version = ">= 1.5.6"
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.32.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  access_key = "AKIAZEDJODE3LZSQ3WIU"
  secret_key = "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"
}





