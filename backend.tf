terraform {
  backend "remote" {
    organization = "homelabmcn" # https://app.terraform.io/app/organizations

    workspaces {
      name = "terraform-proxmox-debian-syspass-dev"
    }
  }
}