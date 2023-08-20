terraform {
  backend "s3" {
    bucket         = "memops-terraform-state-bucket"
    key            = "key"
    region         = "eu-central-1"
    dynamodb_table = "my-terraform-state-lock"
    # Other configurations ...
  }
}

provider "aws" {
  region = "eu-central-1"
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-tf-test-bucket"
}
resource "aws_s3_bucket_acl" "my_bucket_acl" {
  bucket = aws_s3_bucket.my_bucket.bucket
  acl    = "private"
}

resource "aws_db_instance" "default_db" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t2.micro"
#   name                 = "tododb"
  username             = "username"
  password             = "yourpassword"
#    parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
}

resource "aws_route53_zone" "main" {
  name = "kubernetes.quest"
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "my-cluster"
  cluster_version = "1.21" 
   subnet_ids  = concat(aws_subnet.eks_public_subnet.*.id, aws_subnet.eks_private_subnet.*.id)
   eks_managed_node_groups  = {
    eks_nodes = {
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 1

      instance_type = "m5.large"
      private_subnets = [
        aws_subnet.eks_private_subnet[0].id,
        aws_subnet.eks_private_subnet[1].id
      ] 
    }
  }
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group id attached to the EKS cluster."
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name attached to EKS cluster."
  value       = module.eks.cluster_iam_role_name
}

resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "eks_vpc"
  }
}

# Public Subnets
resource "aws_subnet" "eks_public_subnet" {
  count = 2 # Create 2 public subnets

  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "eks_public_subnet-${count.index + 1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id
}

# Route table for public subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_route_table"
  }
}

resource "aws_route_table_association" "public_route_table_association" {
  count          = 2
  subnet_id      = aws_subnet.eks_public_subnet[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

# Private Subnets
resource "aws_subnet" "eks_private_subnet" {
  count = 2 # Create 2 private subnets

  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = "10.0.${count.index + 3}.0/24"

  tags = {
    Name = "eks_private_subnet-${count.index + 1}"
  }
}

# NAT Gateway
resource "aws_eip" "nat" {
  count = 2
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  count         = 2
  subnet_id     = aws_subnet.eks_public_subnet[count.index].id
  allocation_id = aws_eip.nat[count.index].id
}

# Route table for private subnets
resource "aws_route_table" "private_route_table" {
  count = 2
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "private_route_table-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private_route_table_association" {
  count          = 2
  subnet_id      = aws_subnet.eks_private_subnet[count.index].id
  route_table_id = aws_route_table.private_route_table[count.index].id
}
