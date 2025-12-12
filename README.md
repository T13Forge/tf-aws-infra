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
- AWS Secrets Manager for secure credential storage (RDS password, Mailgun API key)
- KMS Customer-Managed Keys (CMK) for encryption at rest (EC2 EBS, RDS, S3, Secrets Manager)
- Lambda function for email sending (triggered by SNS)
- SNS topic for user signup notifications
- DynamoDB table for email deduplication

### Key Features

- Modular, readable configuration
- Supports multiple environments (dev, demo) via separate .tfvars files
- Terraform Workspaces to isolate states
- No hardcoded values — variables and inputs are fully parameterized
- End-to-end encryption using customer-managed KMS keys
- Secure credential management via AWS Secrets Manager

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
    db_name              = ""
    db_username          = ""
    db_port              = 5432

    # Email configuration
    verifiedSenderEmail  = "noreply@yourdomain.com"
    verificationEndPoint = "https://dev.yourdomain.com"
    mailgun_domain       = "mg.yourdomain.com"
    mailgun_api_key      = "your-mailgun-api-key"
    demo_certificate_arn = ""  # Leave empty to auto-detect from ACM

    # Domain
    domain_name          = "dev.yourdomain.com"

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
  - Deployed in public subnets across multiple AZs

- **Target Group**  
  Contains the backend EC2 instances managed by the Auto Scaling Group.  
  ALB forwards requests to targets based on health checks.
  - Healthy threshold: 2 consecutive successes
  - Unhealthy threshold: 2 consecutive failures

- **Launch Template**  
  Defines the EC2 configuration used by the ASG, including:
  - AMI ID (custom image built via Packer)
  - Instance type
  - IAM role (for S3 access)
  - user_data (to install and start the web app)
  - Security group (only allows inbound traffic from ALB SG)
  - Root EBS volume encrypted with customer-managed KMS key

- **Auto Scaling Group (ASG)**  
  Automatically manages EC2 instance count based on CPU utilization.  
  - Minimum, desired, and maximum capacity defined in variables  
  - Health check type: EC2 + ELB  
  - Spans multiple private subnets for high availability
  - Cooldown period: 60 seconds
  - Spans multiple public subnets across different AZs for high availability

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
  - Ingress: 
    - TCP on app port (e.g., 8081) from ALB security group only
    - TCP 22 (SSH) from your IP only (if `var.enable_ssh = true`, restricted to `var.my_ip_cidr`)
  - Egress: All outbound traffic allowed
- Public IP: Automatically assigned (associate_public_ip_address = true)

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
  - Retrieves its configuration (environment variables, database endpoint) via `user_data.sh`
  - Retrieves RDS password from AWS Secrets Manager (encrypted with KMS)
  - Connects securely to RDS in private subnets
  - Uses the attached IAM Role to upload images to the S3 bucket
  - Can publish messages to SNS topic for user signup notifications

### EC2 ↔️ RDS Integration

All EC2 instances launched by the Auto Scaling Group connect to RDS using environment variables passed through `user_data.sh`.  
Each instance runs in private subnets with outbound access through the NAT gateway.

- The EC2 instance connects to RDS on startup via user_data.sh, which injects RDS environment variables into the application’s .env file:
- The EC2 instance must be launched in a public subnet, while RDS remains in private subnets.
- The EC2 security group is whitelisted in the RDS SG to allow inbound PostgreSQL traffic (port 5432).

### EC2 IAM Role & Instance Profile

- S3 Access: Upload, read, delete, and list objects in the images bucket (least-privilege policy)
- Secrets Manager: Read RDS master password secret
- KMS: Decrypt secrets and EBS volumes (for EC2, RDS, S3, and Secrets Manager keys)
- SNS: Publish messages to user signup topic
- CloudWatch: Create log groups/streams and send metrics (CloudWatch Agent)
- SSM: Systems Manager access for instance management without SSH

The IAM role is attached to instances via Instance Profile, allowing the web app to securely access AWS services without hardcoding credentials.

---

## 🔐 AWS Secrets Manager

This infrastructure uses AWS Secrets Manager to securely store sensitive credentials.

### Secrets Stored

1. RDS Master Password
2. Mailgun API Key

### Access Control

- EC2 IAM role has permissions to read RDS secret
- Lambda IAM role has permissions to read Mailgun secret
- Both roles have KMS decrypt permissions for the secrets key
- Secrets are encrypted at rest using customer-managed KMS keys

---

## 🔑 KMS (Key Management Service)

This infrastructure uses customer-managed KMS keys (CMK) for encryption at rest across multiple services.

### KMS Keys Created

1. EC2 EBS Encryption Key
2. RDS Encryption Key
3. S3 Bucket Encryption Key
4. Secrets Manager Encryption Key

### Key Features

- All keys have automatic rotation enabled (90-day period)
- Keys use least-privilege access policies
- Keys are region-specific and cannot be exported
- All encrypted resources continue to work seamlessly after key rotation (via aliases)

---

## 🐘 RDS (PostgreSQL)

This Terraform configuration now provisions an Amazon RDS PostgreSQL instance in the private subnet for secure backend storage.

RDS Configuration Overview

- Engine: PostgreSQL 16.x
- Storage: GP3 (20GB)
- Public Access: Disabled
- Multi-AZ: Disabled (for dev/demo environments)
- Security Group: Allows inbound traffic only from EC2’s security group on port 5432
- Database credentials (username, DB name, port) are read from your *.tfvars files

## 🪣 S3 Bucket

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

## 📧 Lambda Function & SNS (Email Sending)

The infrastructure includes a serverless email sending system using Lambda and SNS.

### Email Flow

1. User signs up via web application
2. EC2 application publishes message to SNS topic (user-signup-topic)
3. SNS invokes Lambda function asynchronously
4. Lambda function

---

## 🗄️ DynamoDB

A DynamoDB table is used for email deduplication to prevent sending duplicate verification emails.

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

## 💥 Setup HTTPS Certificate with AWS Certificate Manager (ACM)

The ALB automatically uses HTTPS with ACM certificates. You can either:

### Option 1: Auto-Detect Certificate (Recommended)

If var.demo_certificate_arn is empty, Terraform will automatically detect the most recent issued certificate for your domain:

```sh
demo_certificate_arn = ""  # Leave empty for auto-detection
domain_name          = "dev.yourdomain.com"
```

### Option 2: Import External Certificate

If you do not already have an SSL certificate in ACM, you can generate a Let's Encrypt certificate using Certbot.
This example uses a single-domain certificate for demo.yourdomain.me:

```sh
sudo certbot certonly \
  --manual \
  --preferred-challenges dns \
  -d demo.yourdomain.me
```

This command uses DNS TXT record validation, and Certbot does not start a web server (no need for port 80).
After completing the DNS verification step, Certbot will generate certificate files under:

```
/etc/letsencrypt/live/yourdomain.com/
```

### Certificate files generated by Certbot

- cert.pem — domain certificate
- privkey.pem — private key
- chain.pem — intermediate CA chain
- fullchain.pem — certificate + chain (recommended for ACM)

### Import the certificate into AWS ACM:

```sh
aws acm import-certificate \
  --certificate fileb://your_domain.crt \
  --certificate-chain fileb://your_domain.ca-bundle \
  --private-key fileb://your_domain.key \
  --region us-east-1 \
  --tags Key=Name,Value=demo-letsencrypt Key=Environment,Value=demo
```

Once imported, you can attach the certificate to your Application Load Balancer (ALB) HTTPS listener. Set the ARN in your .tfvars file:

```
demo_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abc123..."
```

---

## 🌐 Outputs

After deployment, Terraform prints key identifiers. You can view them via: terraform output

### Network & VPC

- current_workspace - Current Terraform workspace name
- vpc_id - VPC ID
- public_subnets - List of public subnet IDs
- private_subnets - List of private subnet IDs
- igw_id - Internet Gateway ID
- route_tables - Map of public and private route table IDs

### Application Access

- alb_dns_name - Public DNS name of the Application Load Balancer
- app_url - Full application URL via Route 53 (e.g., http://dev.yourdomain.com)
- hosted_zone_id - Route 53 hosted zone ID

### Load Balancing & Auto Scaling

- target_group_arn - ARN of the Target Group used by the ALB
- health_check_path - Health check path used by the Target Group
- asg_name - Name of the Auto Scaling Group
- asg_capacity - ASG capacity (min / desired / max)
- launch_template_id - ID of the Launch Template used by ASG
- launch_template_versions - Default and latest Launch Template versions

### Security

- application_sg_id - Application security group ID
- security_group_ids - Map of security group IDs (alb_sg, app_sg, db_sg)

### Database

- rds_endpoint - RDS endpoint hostname
- rds_port - RDS port number

### Monitoring

- cloudwatch_alarms - Map of CloudWatch alarm names (cpu_high, cpu_low)

---

## 🧠 Notes

- Keep your CIDR blocks unique across workspaces (10.0.0.0/16, 10.1.0.0/16, etc.)
- Add ${terraform.workspace} in resource tags to easily identify which workspace created which resource in AWS.
- Terraform automatically stores workspace states in: `terraform.tfstate.d/<workspace>/terraform.tfstate`
- EC2 instances are deployed in public subnets (not private) to allow direct internet access for package updates
- All sensitive data (RDS passwords, API keys) are stored in AWS Secrets Manager, encrypted with KMS
- All storage (EBS, RDS, S3) is encrypted at rest using customer-managed KMS keys
- HTTP traffic is automatically redirected to HTTPS for secure communication

---

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

4. Confirm your upload img request in the collection references the file correctly: `"src": ["imgs/image.png"]`

---

## 🚀 Run Load Test with Newman

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
