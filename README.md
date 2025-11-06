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
- Application Load Balancer (ALB) with security group for HTTP/HTTPS traffic
- Target Group and Health Checks (e.g., /healthz)
- Launch Template defining EC2 configuration (AMI, user_data, IAM role, etc.)
- Auto Scaling Group (ASG) managing EC2 instances across private subnets
- CloudWatch Alarms (CPU utilization) triggering scale in/out
- Route 53 DNS record pointing to the ALB DNS name

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

## Application Load Balancer & Auto Scaling Group (replaces single EC2)

The previous single-EC2 setup is now replaced by a load-balanced, auto-scaled design.

### Components Overview

- **Application Load Balancer (ALB)**  
  Handles incoming HTTP/HTTPS traffic from the internet and distributes requests to healthy EC2 instances in private subnets.
  - Publicly accessible via port 80/443
  - Health check path: `/healthz` (configurable via `var.health_check_path`)
  - Security group allows inbound 80/443 from the internet

- **Target Group**  
  Contains the backend EC2 instances managed by the Auto Scaling Group.  
  ALB forwards requests to targets based on health checks.

- **Launch Template**  
  Defines the EC2 configuration used by the ASG, including:
  - AMI ID (custom image built via Packer)
  - Instance type
  - IAM role (for S3 access)
  - user_data (to install and start the web app)
  - Security group (only allows inbound traffic from ALB SG)

- **Auto Scaling Group (ASG)**  
  Automatically manages EC2 instance count based on CPU utilization.  
  - Minimum, desired, and maximum capacity defined in variables  
  - Health check type: EC2 + ELB  
  - Spans multiple private subnets for high availability

- **CloudWatch Alarms**  
  Trigger scale-out when CPU > 5%, and scale-in when CPU < 3% (example values).  
  These alarms are linked to the ASG policy.

- **Route 53 DNS**  
  Points a friendly domain name (e.g. `dev.isaactai13.me`) to the ALB DNS name via an A record.

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

- When you run terraform apply, the Launch Template and Auto Scaling Group are created.
The ASG automatically launches EC2 instances (using the custom AMI built via Packer) into private subnets.
- These instances are not directly accessible via public IP.
Instead, traffic enters through the Application Load Balancer (ALB),
which is deployed in public subnets and routes requests to the healthy instances in the private subnets.
- The ALB health check path (defined by var.health_check_path, e.g., /healthz)
ensures that only healthy EC2 instances receive traffic.
- The Route 53 record (e.g. dev.isaactai13.me) maps to the ALB DNS name,
so users can access your application via a friendly domain.
- The Auto Scaling Group dynamically adjusts the number of EC2 instances based on CloudWatch CPU metrics:
  - Scale out when average CPU > threshold (e.g., 5%)
  - Scale in when CPU < threshold (e.g., 3%)
- Each new instance launched by the ASG automatically:
  - Retrieves its configuration (environment variables, database endpoint) via user_data.sh
  - Connects securely to RDS in private subnets
  - Uses the attached IAM Role to upload images to the S3 bucket

### EC2 ↔️ RDS Integration

All EC2 instances launched by the Auto Scaling Group connect to RDS using environment variables passed through `user_data.sh`.  
Each instance runs in private subnets with outbound access through the NAT gateway.

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

## 🧩 Scaling Behavior

This setup implements dynamic scaling for web application instances:

- **Scale Out**: Triggered when average CPU utilization exceeds threshold (e.g., 5%)
- **Scale In**: Triggered when CPU utilization falls below threshold (e.g., 3%)
- **CloudWatch Alarms** are defined in Terraform and linked to the ASG
- **Launch Template** ensures that every new instance boots with the correct app and configuration

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

當然可以 👍
以下是完整可直接貼進你 README 的 Markdown 版本（語法正確、排版一致）👇

⸻


## 🧪 Postman & Newman Testing

After the infrastructure is deployed, you can run automated API load tests using **Postman + Newman**.

### 🧩 Setup

1. Make sure you have **Node.js** and **Newman** installed:

```bash
npm install -g newman
```

2. In your project root, create a folder named imgs and place a test image inside:

```bash
mkdir imgs
cp ~/Desktop/image.png imgs/
```

3. Export your Postman collection and environment files:

- NU_6255_Cloud_Automation.postman_collection.json
- env.json (your Postman environment variables)

4. Confirm your upload img request in the collection references the file correctly:

"src": ["imgs/image.png"]


🚀 Run Load Test with Newman

Execute the following command in your project directory:

```sh
newman run NU_6255_Cloud_Automation.postman_collection.json \
  -e env.json \
  --working-dir . \
  --iteration-count 1000
```

- --working-dir . ensures Newman can locate the image under imgs/
- --iteration-count 1000 simulates repeated requests (use smaller values for quick tests)
- Your collection scripts will automatically create users, products, upload images, and verify API correctness for each iteration.

---

## 🧹 Clean Up

To destroy the specific Workspace's infrastructure, select and destroy only that workspace's env

```shell
terraform workspace select demo
terraform destroy -var-file="demo.tfvars"
```
