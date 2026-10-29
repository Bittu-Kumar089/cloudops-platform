data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "cloudops" {
  name        = "cloudops-security-group"
  description = "CloudOps demo network access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP web traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH deployment access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound access for updates and image pulls"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/cloudops/application"
  retention_in_days = 7
}

resource "aws_iam_role" "ec2_role" {
  name = "cloudops-ec2-role"

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

resource "aws_iam_role_policy" "cloudwatch_policy" {
  name = "cloudops-cloudwatch-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.application.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "cloudops" {
  name = "cloudops-instance-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "cloudops" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.cloudops.id]
  iam_instance_profile   = aws_iam_instance_profile.cloudops.name

  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    apt-get update
    apt-get install -y docker.io curl

    systemctl enable --now docker
    usermod -aG docker ubuntu

    curl -fsSLo /tmp/amazon-cloudwatch-agent.deb \
      https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb

    dpkg -i /tmp/amazon-cloudwatch-agent.deb

    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONFIG'
    {
      "metrics": {
        "namespace": "CloudOps",
        "append_dimensions": {
          "InstanceId": "$${aws:InstanceId}"
        },
        "aggregation_dimensions": [["InstanceId"]],
        "metrics_collected": {
          "mem": {
            "measurement": ["mem_used_percent"],
            "metrics_collection_interval": 60
          },
          "disk": {
            "measurement": ["used_percent"],
            "resources": ["/"],
            "metrics_collection_interval": 60
          }
        }
      }
    }
    CWCONFIG

    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config \
      -m ec2 \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
      -s
  EOF

  depends_on = [
    aws_iam_role_policy.cloudwatch_policy,
    aws_cloudwatch_log_group.application
  ]

  tags = {
    Name        = "cloudops-server"
    Environment = "demo"
    Project     = "CloudOps"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "cloudops-high-cpu"
  alarm_description   = "CPU utilization is above 70 percent"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 70
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    InstanceId = aws_instance.cloudops.id
  }

  treat_missing_data = "notBreaching"
}