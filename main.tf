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
      version = "~> 5.14.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}





