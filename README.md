This repository demonstrates a Terraform + Azure setup that runs through GitHub Actions with OpenID Connect (OIDC) authentication and a remote state stored in an Azure Storage Account. Four deployment environments are provided out of the box: `dev`, `int`, `crt`, and `prd`.

## Repository layout

- `main.tf` – sample Azure Resource Group that incorporates the `environment` suffix.
- `providers.tf` – Terraform backend/provider configuration (backend values are supplied at runtime).
- `variables.tf` – shared variables (`location`, `environment`).
- `environments/<env>/terraform.tfvars` – per-environment variables.
- `environments/<env>/backend.hcl` – remote backend settings; update the placeholder values with your storage account details before running Terraform.
- `.github/workflows/terraform-plan.yml` – pull request validation that formats, validates, and plans against all environments.
- `.github/workflows/terraform-apply.yml` – applies to `dev` automatically on merges to `main`; other environments are promoted via the `workflow_dispatch` input and GitHub Environment approvals.

## Quickstart — GitHub configuration

1. **Create GitHub Environments**  
   Navigate to *Settings → Secrets and variables → Environments* and create environments named `dev`, `int`, `crt`, and `prd`. Configure environment protection (e.g., required reviewers) for `crt`/`prd` as needed.

2. **Add environment secrets**  
   Add the following secrets to each GitHub Environment (values differ per environment only if you scope access differently):
   - `AZURE_CLIENT_ID` – Azure AD application (service principal) client ID.
   - `AZURE_TENANT_ID` – Azure AD tenant ID.
   - `AZURE_SUBSCRIPTION_ID` – subscription ID that Terraform manages.

3. **Update backend configuration files**  
   Edit each `environments/<env>/backend.hcl` file and replace the placeholder values with your state resource group, storage account, and container. Each file already sets a unique `key` so that every environment stores state independently.

4. **Connect Azure AD to GitHub Actions**  
   Create (or reuse) an Azure AD application, then configure one federated credential per GitHub environment using the subject format `repo:<org>/<repo>:environment:<env>`. Grant the service principal:
   - `Storage Blob Data Contributor` on the storage account that hosts Terraform state.
   - `Contributor` (or a more restrictive custom role) scoped to the resources each environment should manage.

## Workflow behaviour

- **terraform-plan.yml** runs on pull requests, iterating over `dev`, `int`, `crt`, and `prd`. Each job:
  1. Authenticates to Azure using OIDC.
  2. Inits Terraform with the matching backend file.
  3. Runs `terraform fmt -check`, `terraform validate`, and `terraform plan`, uploading one plan artifact per environment.

- **terraform-apply.yml** runs on:
  - `push` to `main`, automatically applying to `dev`.
  - Manual `workflow_dispatch`, allowing promotion to `dev`, `int`, `crt`, or `prd`. GitHub Environment protections gate access and approvals before secrets are released.

## Running Terraform locally

```bash
# Authenticate with Azure (e.g., az login) and export subscription/tenant if required.
terraform init -backend-config=environments/dev/backend.hcl
terraform plan -var-file=environments/dev/terraform.tfvars -var="environment=dev"
terraform apply
```

Swap `dev` for another environment to work against different state files and variables.

## Security recommendations

- Keep the Azure AD service principal scoped to the minimum necessary resources per environment.
- Require reviewers for `crt`/`prd` environments in GitHub to introduce manual gates for production changes.
- Rotate federation credentials and review audit logs periodically.

## Optional extensions

- Add a scheduled drift detection workflow that runs `terraform plan -detailed-exitcode`.
- Capture deployment metadata (e.g., plan summaries) in storage or monitoring for traceability.
- Manage Azure AD application, federated credentials, and RBAC assignments as code in Terraform.
