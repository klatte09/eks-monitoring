resource "aws_security_group" "my_app" {
  name        = "my-app"
  description = "Allow My App Access"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow Node Exporter Access"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.demo.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description = "Allow SSH Access"
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

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "my_app" {
  ami                    = "ami-0283a57753b18025b"
  instance_type          = "t2.medium"
  key_name               = "ohiokey"
  subnet_id              = aws_subnet.public_us_east_2a.id
  vpc_security_group_ids = [aws_security_group.my_app.id]

  user_data = <<EOF
#!/bin/bash

sudo -s
useradd --system --no-create-home --shell /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz
tar -xvf node_exporter-1.3.1.linux-amd64.tar.gz
mv node_exporter-1.3.1.linux-amd64/node_exporter /usr/local/bin/

cat <<EOT >> /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOT

systemctl enable node_exporter
systemctl start node_exporter
EOF

  tags = {
    Name          = "My App"
    node-exporter = "true"
  }
}
