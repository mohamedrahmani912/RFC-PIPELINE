terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  
  backend "azurerm" {
    # Configuration via variables d'environnement
  }
}

provider "azurerm" {
  features {}
  # Utilise l'authentification Azure CLI automatiquement
}