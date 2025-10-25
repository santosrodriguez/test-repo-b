resource_group_name  = ${{ vars.AZURE_CLIENT_ID }}
storage_account_name = ${{ vars.AZURE_STORAGE_ACCOUNT }}
container_name       = ${{ vars.AZURE_STORAGE_CONTAINER }}
key                  = "tfstate-dev/terraform.tfstate"