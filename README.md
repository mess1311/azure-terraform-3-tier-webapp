# 3-Tier Azure Web App — Terraform 

## Install Terraform and sign in to Azure

1. **Install the Azure CLI** (if you don't have it) — Terraform uses your
   CLI login to authenticate, so you don't manage separate credentials.
   Follow: https://learn.microsoft.com/cli/azure/install-azure-cli

2. **Install Terraform** — download from
   https://developer.hashicorp.com/terraform/install and follow the
   instructions for your OS. Verify it worked:
   ```bash
   terraform version
   ```

3. **Sign in to Azure:**
   ```bash
   az login
   ```
   This opens a browser window. Once signed in, Terraform's `azurerm`
   provider will automatically use this session — you never type an Azure
   password into any `.tf` file.

4. **If you have more than one subscription**, set the one you want to
   deploy into:
   ```bash
   az account list --output table
   az account set --subscription "<subscription-id-or-name>"
   ```

---

## Understand the files in this project

```
azure-terraform-3-tier-webapp/
├── modules/
├────── network.tf                  # resource group, VNet, subnets, NSGs
├────── sql.tf                       # Azure SQL + private endpoint
├────── monitoring.tf                 # Log Analytics + Application Insights
├────── appservice.tf                  # App Service Plan + backend/frontend apps
├────── appgateway.tf                   # WAF Application Gateway
├────── autoscale.tf                     # autoscale rules              
├── providers.tf              # Terraform + provider configuration
├── variables.tf               # input variables (things you can customize)
├── outputs.tf                        # values printed after a successful apply
├── terraform.tfvars.example           # template for your own variable values
└── .gitignore
```


---

## Set your variables

1. Copy the example variables file:
   ```bash
   cd azure-terraform-3-tier-webapp
   cp terraform.tfvars.example terraform.tfvars
   ```
2. Open `terraform.tfvars` and change `unique_suffix` to something only you
   would pick (e.g. your initials + a few digits) — several resources
   (like the SQL server and App Services) need globally unique names
   across all of Azure, and this suffix is how we guarantee that.

3. **For the SQL password, don't put it in the file at all.** The
   cleanest beginner-safe way to supply a sensitive variable is an
   environment variable, using the pattern `TF_VAR_<variable name>`:
   ```bash
   export TF_VAR_sql_admin_password='ChooseA-Strong1!Password'
   ```
   Terraform automatically picks up any environment variable named
   `TF_VAR_something` and uses it for the matching variable in
   `variables.tf`. This keeps the password out of any file you might
   accidentally commit or share.

---

## Run Terraform

Run these commands **in order**, from inside the `terraform-infra` folder.

### 1. `terraform init`
```bash
terraform init
```
**What this does:** downloads the `azurerm` provider plugin (defined in
`providers.tf`) into a local `.terraform/` folder. You run this once per
project, and again any time you change provider versions. Think of it
like `npm install` for a Node project — it's fetching the tooling your
code depends on, not touching Azure at all yet.

### 2. `terraform fmt` 
```bash
terraform fmt
```
Auto-formats your `.tf` files for consistent indentation/spacing. Doesn't
change any logic — purely cosmetic.

### 3. `terraform validate`
```bash
terraform validate
```
Checks your files for syntax errors and basic correctness (e.g. missing
required arguments) — again, without touching Azure. Fix anything it
flags before moving on.

### 4. `terraform plan`
```bash
terraform plan
```

### 5. `terraform apply`
```bash
terraform apply
```
---

## Deploy your app code

Terraform builds the *infrastructure*, not your application code. Deploy
the backend and frontend apps from the earlier parts of this project the
same way as with the Bicep version:

```bash
# Backend
cd ../backend-api
zip -r app.zip . -x "node_modules/*" ".git/*"
az webapp deploy --resource-group rg-3tier-webapp-tf \
  --name app-3tier-backend-<yoursuffix> \
  --src-path app.zip --type zip

# Frontend — update BACKEND_URL in public/app.js first, then:
cd ../frontend-app
zip -r app.zip . -x "node_modules/*" ".git/*"
az webapp deploy --resource-group rg-3tier-webapp-tf \
  --name app-3tier-frontend-<yoursuffix> \
  --src-path app.zip --type zip
```

---

## Making changes 

Say you want to change the autoscale minimum from 2 to 3 instances. You'd
edit the `minimum = "2"` line in `autoscale.tf` to `"3"`, then run:

```bash
terraform plan
```

You'll see Terraform detect *only* that one change — it doesn't touch
anything else, because nothing else in your `.tf` files changed. This is
the entire point of "infrastructure as code": changes are precise,
reviewable before they happen, and repeatable.

---

## About the state file and secrets (read before sharing this repo)

Your `terraform.tfstate` file, created after `terraform apply`, contains
the SQL admin password in **plain text** — this is a known, normal
characteristic of how Terraform state works, not a bug in this project.

For a solo learning project, this is an acceptable trade-off as long as
you:
- Never commit `terraform.tfstate` to git (already excluded via
  `.gitignore` in this project)
- Don't share the file

For a real production project, or if you want to mention this properly in
an interview, the standard fixes are:
- **Remote state with encryption**: store `terraform.tfstate` in an Azure
  Storage Account container instead of your local disk (a "remote
  backend"), which supports encryption at rest and access control. This
  also lets a team share one state file safely.
- **Key Vault for secrets**: instead of passing the SQL password through
  a Terraform variable at all, generate/store it in Azure Key Vault and
  have the App Service read it via a Key Vault reference in its
  connection string — the secret then never flows through Terraform's
  state file in the first place.

Both are natural "Phase 2" additions if you want to extend this project
further for your resume.

---

## Destroy

When you're done experimenting:

```bash
terraform destroy
```

---

