terraform { 
 backend "azurerm" {
    resource_group_name  = "rg-project2-dr"
    storage_account_name = "stproject2dr"
    container_name = "tfstate"
    key = "project2.terraform.tfstate" //just name for the tf state ... could be anything
  }
}