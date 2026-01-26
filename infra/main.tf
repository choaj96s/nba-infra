provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

############################
# AMI
############################
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

############################
# ECR
############################
resource "aws_ecr_repository" "nba_backend" {
  name = "nba-backend"
}

############################
# IAM
############################
resource "aws_iam_role" "ec2_role" {
  name = "nba-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "ecr_read_only" {
  name = "nba-ecr-read-only"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "secrets_read_only" {
  name        = "nba-secrets-read-only"
  description = "Allow EC2 to read secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:nba/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ecr" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ecr_read_only.arn
}

resource "aws_iam_role_policy_attachment" "ec2_secrets" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets_read_only.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "nba-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

############################
# Security Group
############################
resource "aws_security_group" "ec2_sg" {
  name        = "nba-ec2-sg"
  description = "Allow HTTP 8080"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################
# EC2 Instance
############################
resource "aws_instance" "backend" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = aws_key_pair.ec2_key.key_name

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo amazon-linux-extras install docker -y
              sudo service docker start
              sudo usermod -a -G docker ec2-user

              # Docker Compose 설치
              sudo curl -L "https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              sudo chmod +x /usr/local/bin/docker-compose

              # ECR 로그인
              aws ecr get-login-password --region ${var.aws_region} \
                | docker login --username AWS --password-stdin ${aws_ecr_repository.nba_backend.repository_url}

              # docker-compose.yml 생성
              cat > /home/ec2-user/docker-compose.yml << 'EOC'
              version: "3.9"

              services:
                redis:
                  image: redis:7
                  container_name: redis
                  ports:
                    - "6379:6379"
                  restart: unless-stopped
                  healthcheck:
                    test: ["CMD", "redis-cli", "ping"]
                    interval: 5s
                    timeout: 2s
                    retries: 5

                backend:
                  image: 997754089670.dkr.ecr.us-west-2.amazonaws.com/nba-backend:latest
                  container_name: nba-backend
                  ports:
                    - "8080:8080"
                  environment:
                    SPRING_PROFILES_ACTIVE: dev
                    SPRING_REDIS_HOST: redis
                    SPRING_REDIS_PORT: 6379
                  depends_on:
                    redis:
                      condition: service_healthy
              EOC

              cd /home/ec2-user
              sudo systemctl start docker
              EOF

  tags = {
    Name = "nba-backend"
  }
}

