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
- RDS PostgreSQL instance in private subnets (with DB subnet group & SG)
- IAM Role and Instance Profile for EC2 to access S3
- S3 bucket for product image storage

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
    region          = "us-east-1"
    vpc_name        = ""
    vpc_cidr        = "10.0.0.0/16"
    app_port        = 8081
    public_key_path = "~/.ssh/aws_key.pub"
    name_prefix     = "app-sg-dev"
    ami_id          = ""
    subnet_tier     = "public"
    target_az       = "us-east-1a"

    # DB
    db_name              = "csye6225"
    db_username          = "dbadmin"
    db_port              = 5432

    tags = {
      Project = ""
      Owner   = ""
    }
  ```

---

## EC2 Instance

This Terraform setup also provisions an EC2 instance inside the created VPC.

EC2 Configuration Overview

- AMI: Ubuntu 20.04 LTS (or your custom AMI)
- Instance Type: t3.micro
- Root Volume: 25 GB GP2 (auto deleted on termination)
- SSH Key Pair: Generated from your local public key (aws_key_pair)
- Subnet Placement: Dynamically selected by tier (public/private) and Availability Zone
- Security Group:
  - Ingress: TCP 22 (SSH), 80 (HTTP), 443 (HTTPS), and 8081 (your web app port)
  - Egress: All outbound traffic allowed

### How It Works

- The public key defined in public_key_path will be uploaded to AWS as an EC2 Key Pair.
You can later connect using:

  ```shell
  ssh -i ~/.ssh/aws_key.pem ubuntu@<EC2-Public-IP>
  ```

- The EC2 instance will be launched in the public subnet of the selected Availability Zone.
If you set subnet_tier = "private", it will launch in the private subnet instead (without public IP).
- The app_port (e.g. 8081) defines the custom application port opened in the security group.

### EC2 ↔️ RDS Integration

- The EC2 instance connects to RDS on startup via user_data.sh, which injects RDS environment variables into the application’s .env file:
- The EC2 instance must be launched in a public subnet, while RDS remains in private subnets.
- The EC2 security group is whitelisted in the RDS SG to allow inbound PostgreSQL traffic (port 5432).

### EC2 IAM Role & Instance Profile

- EC2 assumes an IAM Role with S3 access permissions (policy described in the S3 section).
- The IAM role is attached to the instance via Instance Profile.
- This allows the web app to securely upload and delete images on S3 without hardcoding AWS credentials.

## 🐘 RDS (PostgreSQL)

This Terraform configuration now provisions an Amazon RDS PostgreSQL instance in the private subnet for secure backend storage.

RDS Configuration Overview

- Engine: PostgreSQL 16.x
- Storage: GP3 (20GB)
- Public Access: Disabled
- Multi-AZ: Disabled (for dev/demo environments)
- Security Group: Allows inbound traffic only from EC2’s security group on port 5432
- Database credentials (username, DB name, port) are read from your *.tfvars files

## S3 Bucket

An S3 bucket is created to store product images uploaded through the web application.

Configuration Overview

- Bucket name is prefixed with your environment (e.g., dev-csye6225-webapp-bucket)
- Versioning: Enabled
- Block Public Access: Enabled
- IAM policy allows EC2 instances (via instance profile) to:
  - Upload (PutObject)
  - Read (GetObject)
  - Delete (DeleteObject)
  - List (ListBucket)

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

```txt
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

```txt
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
- public_subnets = []
- private_subnets = []
- igw_id
- route_tables
- chosen_subnet_id
- chosen_az
- application_sg_id
- instance_id
- rds_endpoint
- rds_port

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
