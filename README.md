# AWS Networking Infrastructure with Terraform

This project sets up a complete AWS networking environment using Terraform.
It creates a Virtual Private Cloud (VPC) with public and private subnets, Internet Gateway, and route tables across multiple Availability Zones.

---

## 📘 Overview

Infrastructure Includes

- VPC (aws_vpc.csye6225)
- 3 Public subnets and 3 Private subnets, each in a different AZ
- Internet Gateway (IGW) attached to the VPC
- Public Route Table (0.0.0.0/0 → IGW)
- Private Route Table (internal routing only)
- Modular Terraform structure (separate .tf files for each resource type)

Key Features
- Modular, readable configuration
- Supports multiple environments (dev, demo) via separate .tfvars files
- No hardcoded values — variables and inputs are fully parameterized

---

## 🗂️ Project Structure

.
├── main.tf
├── providers.tf
├── versions.tf
├── variables.tf
├── dev.tfvars              # dev environment variables
├── demo.tfvars             # demo environment variables
├── vpc.tf
├── subnets.tf
├── igw.tf
├── route_tables.tf
└── outputs.tf

---

⚙️ Prerequisites

- Terraform >= 1.6.0
- AWS CLI installed and configured

```shell
  aws configure --profile dev
  aws configure --profile demo
```

- IAM user or profile with permissions to create VPC, subnets, route tables, and IGWs

---

## 🚀 How to Deploy

### Initialize Terraform

```shell
terraform init
```

### Plan and Apply for Each Environment

- Dev Environment

  ```shell
  terraform plan  -var-file="dev.tfvars"
  terraform apply -var-file="dev.tfvars"
  ```

- Demo Environment

  ```shell
  terraform plan  -var-file="demo.tfvars"
  terraform apply -var-file="demo.tfvars"
  ```

### ⚠️ Important Notes:

- Each .tfvars represents a separate environment configuration.
- Terraform treats all resources defined in this directory as a single state.
- Running apply with a new .tfvars may cause Terraform to destroy and recreate resources if variables (like VPC CIDR) differ.

---

## 🌐 Outputs

After deployment, Terraform prints key identifiers:

- vpc_id
- public_subnets
- private_subnets
- igw_id
- route_tables

You can also view them via: `terraform output`

---

## 🧠 Notes

- Each .tfvars defines values like:

```hcl
  region   = "us-east-1"
  profile  = "dev"
  vpc_name = "dev"
  vpc_cidr = "10.0.0.0/16"
```

- Do not use multiple tfvars with the same workspace — Terraform will treat it as an update, not a new VPC.
- For multiple coexisting VPCs in the same AWS account/region, consider switching to Terraform Workspaces (see next version).

---

## 🧹 Clean Up

To destroy the infrastructure:

```shell
terraform destroy -var-file="dev.tfvars"
```
