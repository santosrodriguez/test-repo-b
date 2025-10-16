This repository demonstrates a minimal Terraform configuration plus a GitHub Actions workflow that:

- Uses OIDC (id-token) to authenticate with Azure (no client secret stored in the repo).
- Stores Terraform variable files per environment in `environments/<env>/terraform.tfvars`.
- Uses GitHub Environments (`dev`, `test`, `prod`) to scope backend secrets and optionally require approvals for PROD.

## Repository layout

- `main.tf` - minimal Azure resource (resource group) which uses `var.location` and includes `var.environment` in the name.
- `providers.tf` - provider and backend configuration (backend receives runtime `-backend-config` values from CI).
- `variables.tf` - `location` and `environment` variables.
- `environments/` - per-environment directories containing `terraform.tfvars` for `dev`, `test`, and `prod`.
- `.github/workflows/terraform.yml` - PR-driven GitHub Actions workflow that reads environment secrets, runs Terraform checks, applies after approval, and merges.

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

3. (Recommended) For the `prod` GitHub Environment, configure required reviewers so that Terraform applies only run after an explicit approval inside GitHub Environments in addition to PR reviews.

4. When opening a pull request, add a label such as `env:dev`, `env:test`, or `env:prod`. The workflow uses this label to choose which environment configuration and secrets to load. You can update the label at any time; the next workflow run will plan/apply against the new target.

## Azure setup notes (high level)

- Create an Azure AD App Registration and configure a federated credential that trusts GitHub Actions for your repository and branches/workflows. The federated credential maps GitHub OIDC tokens to the App Registration without needing a client secret.
- Grant a service principal least-privilege RBAC roles in the target subscription/resource group:
	- Storage Blob Data Contributor on the storage container used for Terraform state.
	- Contributor (or narrower) role scoped to the resources you need to manage for each environment.

## How the workflow works

- The workflow (`.github/workflows/terraform.yml`) runs on `pull_request_target` events. A label such as `env:dev`, `env:test`, or `env:prod` determines which Terraform variables and GitHub Environment secrets to use.
- PR runs execute from the PR head commit, run `terraform fmt -check`, `terraform validate`, and `terraform plan -refresh=false -var-file="environments/<env>/terraform.tfvars"`, then post (or update) a single plan comment on the PR.
- A lightweight status job surfaces whether the plan detected changes directly in the GitHub check results, so reviewers know if they are approving a no-op or a change without opening the comment.
- After an approval review, the workflow re-runs `terraform plan` against the live backend for the same commit, runs `terraform apply`, and merges the PR automatically once the apply succeeds.
- GitHub Environment protection (for example, required reviewers on `prod`) can block the apply step until the environment approval is granted, adding another safeguard.

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
- Upload the detailed plan output as a workflow artifact for auditing after each PR run.
- Schedule a periodic drift-detection workflow (e.g., weekly `terraform plan -detailed-exitcode`) to catch out-of-band changes.

If you'd like, I can add a `docs/` page that walks through creating the federated credential in Azure AD, configuring GitHub Environment protections, and wiring drift detection step-by-step.
