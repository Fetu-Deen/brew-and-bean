# Terraform — Brew & Bean Infrastructure

This Terraform config recreates your ENTIRE Evangadi Coffee Shop architecture from scratch:
VPC, ALB, ECS Fargate, ECR, SNS, 4x SQS queues, 4x Lambdas, 2x DynamoDB tables, S3, WAF.

## What is Terraform?

Terraform reads these `.tf` files and creates/destroys AWS resources to match.
- `terraform apply` = build the whole architecture
- `terraform destroy` = tear down everything (one command!)

## Prerequisites (one-time setup)

1. Install Terraform:
```
For Mac:
brew install terraform
```

2. Make sure AWS CLI is configured 
```
aws sts get-caller-identity
```

## Deploy the full architecture

```
cd terraform
terraform init
terraform plan
terraform apply
```

- `terraform init` downloads the AWS provider plugin (first time only)
- `terraform plan` shows what will be created (dry run, no changes)
- `terraform apply` actually creates everything (type "yes" when prompted)

After apply, it prints the ALB DNS name. Then push your Docker image:
```
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 269742496681.dkr.ecr.us-west-2.amazonaws.com
docker build --platform linux/amd64 -t brew-and-bean-coffee-api .
docker tag brew-and-bean-coffee-api:latest 269742496681.dkr.ecr.us-west-2.amazonaws.com/brew-and-bean-coffee-api:latest
docker push 269742496681.dkr.ecr.us-west-2.amazonaws.com/brew-and-bean-coffee-api:latest
aws ecs update-service --cluster brew-and-bean-cluster --service brew-and-bean-coffee-api-service --force-new-deployment --desired-count 1 --region us-west-2
```

## Tear down EVERYTHING

```
cd terraform
terraform destroy
```

Type "yes" — removes every resource. No more AWS bill.

## Important notes

- The S3 bucket name must be globally unique. If `brew-and-bean-orders-269742496681` is taken,
  change it in `variables.tf`.
- Bedrock model access (Claude Haiku 4.5) must be requested manually in the AWS console —
  Terraform cannot do this. Do it before testing Path D.
- The ECS service starts with `desired_count = 1`. After `apply`, it will pull from ECR —
  you need to push the Docker image first (or the task will fail to start, which is fine,
  it retries once the image is there).
- State is stored locally in `terraform.tfstate`. Don't delete this file while resources exist,
  or Terraform won't know what to destroy.

## File layout
```
terraform/
  provider.tf      — AWS provider + version
  variables.tf     — region, account ID, bucket name
  networking.tf    — VPC, subnets, IGW, route table, security groups
  alb.tf           — Application Load Balancer + target group + listener
  ecr.tf           — ECR repository
  ecs.tf           — ECS cluster, task definition, service
  iam.tf           — All IAM roles (ECS + 4 Lambda roles)
  sns.tf           — SNS topic
  sqs.tf           — 4 SQS queues + SNS subscriptions + queue policies
  dynamodb.tf      — coffee-orders + coffee-recommendations tables
  s3.tf            — S3 bucket for Path C
  lambdas.tf       — 4 Lambda functions + SQS triggers
  waf.tf           — WAF Web ACL + ALB association
  HOW-TO-USE.md    — this file
```
