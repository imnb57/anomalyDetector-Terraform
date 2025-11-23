provider "aws" {
  region = var.aws_region
  
  # credentials are taken from environment / profile / IAM role
}
