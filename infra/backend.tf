terraform {
  backend "s3" {
    bucket         = "nba-infra-terraform-state-ac"
    key            = "nba-infra/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "nba-infra-terraform-lock"
    encrypt        = true
  }
}
