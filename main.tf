terraform {
  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.70"
    }
  }
}

provider "tfe" {
  hostname = "app.terraform.io"
}

resource "tfe_workspace" "example" {
  name         = "shalalalya"
  organization = "Yordanh-Tfc4b"
}
