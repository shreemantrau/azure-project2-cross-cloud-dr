terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = "~> 3.0"
    }
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
  }

}

provider "azurerm"{
    features{} // required even if empty ... this allows it to initate
  }

provider "aws"{
    region = "us-west-2"
  }

