# AWS Networking Infrastructure with Terraform

This project sets up a complete AWS networking environment using Terraform.
It creates a Virtual Private Cloud (VPC) with public and private subnets, Internet Gateway, and route tables across multiple Availability Zones.

---

## 📘 Overview

### Infrastructure Includes

- VPC (aws_vpc.csye6225)
- 3 Public subnets and 3 Private subnets, each in a different AZ
- Internet Gateway (IGW) attached to the VPC
- Public Route Table (0.0.0.0/0 → IGW)
- Private Route Table (internal routing only)
- Modular Terraform structure (separate .tf files for each resource type)

### Key Features

- Modular, readable configuration
- Supports multiple environments (dev, demo) via separate .tfvars files
- Terraform Workspaces to isolate states
- No hardcoded values — variables and inputs are fully parameterized

---

## ⚙️ Prerequisites

- Terraform >= 1.6.0
- AWS CLI installed and configured

  ```shell
    aws configure --profile dev
    aws configure --profile demo
  ```

- IAM user or profile with permissions to create VPC, subnets, route tables, and IGWs
- Create environment-specific variable files (dev.tfvars or demo.tfvars) with the following structure:

  ```hcl
    region   = "us-east-1"
    profile  = "dev"
    vpc_name = "dev"
    vpc_cidr = "10.0.0.0/16"
  ```

---

## 🚀 How to Deploy (with Terraform Workspaces)

Workspaces let you maintain multiple, isolated sets of infrastructure (states)
using the same code and resource names — ideal for creating multiple VPCs in one account/region.

### Step 1 - Initialize Terraform

```shell
terraform init
```

### Step 2 - Create and List Workspaces

```shell
terraform workspace new dev
terraform workspace new demo
terraform workspace list
```

You’ll see something like:

```
  default
* dev
  demo
```

The * indicates your current workspace

### Step 3 - Plan and Apply for Each Environment

- Dev Environment

  ```shell
  terraform workspace select dev
  terraform plan  --var-file="dev.tfvars"
  terraform apply --var-file="dev.tfvars"
  ```

- Demo Environment

  ```shell
  terraform workspace select demo
  terraform plan  --var-file="demo.tfvars"
  terraform apply --var-file="demo.tfvars"
  ```

Terraform will automatically create per-workspace state files under:

```
terraform.tfstate.d/
├── dev/
│   └── terraform.tfstate
└── demo/
    └── terraform.tfstate
```

### ⚠️ Important Notes

😁 This won't happen if you're using workspace!!

- Each .tfvars represents a separate environment configuration.
- Terraform treats all resources defined in this directory as a single state.
- Running apply with a new .tfvars may cause Terraform to destroy and recreate resources if variables (like VPC CIDR) differ.

---

## 🌐 Outputs

After deployment, Terraform prints key identifiers:

- current_workspace
- vpc_id
- public_subnets
- private_subnets
- igw_id
- route_tables

You can also view them via: `terraform output`

---

## 🧠 Notes

- Keep your CIDR blocks unique across workspaces (10.0.0.0/16, 10.1.0.0/16, etc.)
- Add ${terraform.workspace} in resource tags to easily identify which workspace created which resource in AWS.
- Terraform automatically stores workspace states in: `terraform.tfstate.d/<workspace>/terraform.tfstate`

---

## 🧹 Clean Up

To destroy the specific Workspace's infrastructure, select and destroy only that workspace's env

```shell
terraform workspace select demo
terraform destroy -var-file="demo.tfvars"
```
