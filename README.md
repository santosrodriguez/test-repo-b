This repository demonstrates a minimal Terraform configuration plus a GitHub Actions workflow that:

- Uses OIDC (id-token) to authenticate with Azure (no client secret stored in the repo).
- Stores Terraform variable files per environment in `environments/<env>/terraform.tfvars`.
- Uses GitHub Environments (`dev`, `test`, `prod`) to scope backend secrets and optionally require approvals for PROD.

## Repository layout

- `main.tf` - minimal Azure resource (resource group) which uses `var.location` and includes `var.environment` in the name.
- `providers.tf` - provider and backend configuration (backend receives runtime `-backend-config` values from CI).
- `variables.tf` - `location` and `environment` variables.
- `environments/` - per-environment directories containing `terraform.tfvars` for `dev`, `test`, and `prod`.
- `.github/workflows/terraform-environments.yml` - example GitHub Actions workflow that reads environment secrets and runs Terraform.

## Quickstart — what to configure in GitHub

1. Create GitHub Environments
	 - In the repo, go to Settings → Secrets and variables → Environments.
	 - Create `dev`, `test`, `prod` environments.
	 - (Optional) For `prod`, configure protection rules and required reviewers to force manual approvals before secrets are exposed.

2. Add environment secrets (for each environment)
	 - Add the following secrets to each environment (values differ per environment):
		 - `AZURE_CLIENT_ID` — App Registration client id (used by OIDC/federation)
		 - `AZURE_TENANT_ID` — Azure tenant id
		 - `AZURE_SUBSCRIPTION_ID` — subscription id
		 - `AZURE_STORAGE_ACCOUNT` — storage account for backend state
		 - `AZURE_CONTAINER_NAME` — container name for state
		 - `AZURE_RESOURCE_GROUP` — resource group containing the storage account

	 You can also keep these as repository-level secrets temporarily, but environment secrets are recommended for per-environment isolation.

## Azure setup notes (high level)

- Create an Azure AD App Registration and configure a federated credential that trusts GitHub Actions for your repository and branches/workflows. The federated credential maps GitHub OIDC tokens to the App Registration without needing a client secret.
- Grant a service principal least-privilege RBAC roles in the target subscription/resource group:
	- Storage Blob Data Contributor on the storage container used for Terraform state.
	- Contributor (or narrower) role scoped to the resources you need to manage for each environment.

## How the workflow works

- The workflow (`.github/workflows/terraform-environments.yml`) is manually triggered (`workflow_dispatch`) and takes an `env` input (`dev`, `test`, `prod`).
- The job declares `environment: ${{ github.event.inputs.env }}` so GitHub will expose only that environment's secrets to the job and enforce any protection rules.
- The workflow does `terraform init` with `-backend-config` values read from environment secrets and sets a per-environment key like `dev/terraform.tfstate` to isolate state.
- It then runs `terraform fmt -check`, `terraform validate`, and `terraform plan -var-file="environments/${{ github.event.inputs.env }}/terraform.tfvars"`.

## Run it locally (example)

If you want to iterate locally before using GitHub Actions:

1. Create `terraform.tfvars` locally or pass `-var-file` when running Terraform. Example using the environment files:

```bash
terraform init -backend-config="storage_account_name=<account>" -backend-config="container_name=<container>" -backend-config="resource_group_name=<rg>" -backend-config="subscription_id=<sub>" -backend-config="key=dev/terraform.tfstate"
terraform plan -var-file="environments/dev/terraform.tfvars"
```

2. `terraform apply` only after reviewing the plan.

## Security notes and recommendations

- Use per-environment service principals (or at least per-environment RBAC) for least privilege.
- Use GitHub Environment protection rules to require human approval for `prod` runs.
- Avoid committing secrets or backend details; use `-backend-config` via CI secrets instead.

## Next steps you can do

- Add the App Registration and federated credential automation in Terraform.
- Add `terraform fmt` and `validate` checks as part of PR workflows.
- Add `terraform plan -out` and upload the plan artifact so `apply` runs from an approved plan.

If you'd like, I can add a `docs/` page that walks through creating the federated credential in Azure AD and setting the GitHub Environment protections step-by-step.

