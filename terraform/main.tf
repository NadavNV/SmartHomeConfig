# This Terraform script sets up a minimal Kubernetes cluster using EC2 instances
# 1 control plane and 2 worker nodes, each with 10GB EBS
# Ubuntu 22.04 is used for ease of setup

provider "aws" {
  region = var.aws_region # Frankfurt
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "" # Optional: fallback
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig_path
  }
}

variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "eu-central-1"
}

variable "key_name" {
  description = "Name of your existing AWS EC2 key pair"
  type        = string
}

locals {
  common_tags = {
    terraform                          = "true"
    "kubernetes.io/cluster/smart-home" = "owned"
  }
}

resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = merge(local.common_tags, {
    Name = "kube-vpc"
  })
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1a"
  tags = merge(local.common_tags, {
    Name                               = "kube-subnet"
    "kubernetes.io/cluster/smart-home" = "owned"
    "kubernetes.io/role/elb"           = "1"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = local.common_tags
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = local.common_tags
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "kube_sg" {
  name        = "kube-sg"
  description = "Allow Kubernetes ports"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags
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

  owners = ["099720109477"] # Canonical's AWS owner ID
}

resource "aws_ebs_volume" "worker1_root" {
  availability_zone = aws_instance.worker_nodes[0].availability_zone
  size              = 10
  type              = "gp2"
  # volume_id from import
  tags = {
    Name = "k8s-worker-1-root"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "worker1_root_attach" {
  device_name  = "/dev/sda1"
  volume_id    = aws_ebs_volume.worker1_root.id
  instance_id  = aws_instance.worker_nodes[0].id
  force_detach = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ebs_volume" "worker2_root" {
  availability_zone = aws_instance.worker_nodes[0].availability_zone
  size              = 10
  type              = "gp2"
  # volume_id from import
  tags = {
    Name = "k8s-worker-2-root"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "worker2_root_attach" {
  device_name  = "/dev/sda1"
  volume_id    = aws_ebs_volume.worker2_root.id
  instance_id  = aws_instance.worker_nodes[1].id
  force_detach = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ebs_volume" "control_plane_root" {
  availability_zone = aws_instance.control_plane.availability_zone
  size              = 10
  type              = "gp2"

  tags = merge(local.common_tags, {
    Name = "k8s-control-plane-root"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "control_plane_root_attach" {
  device_name = "/dev/sda1"
  volume_id   = aws_ebs_volume.control_plane_root.id
  instance_id = aws_instance.control_plane.id

  force_detach = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_instance" "control_plane" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.kube_sg.id]
  key_name               = var.key_name
  user_data              = <<-EOF
              #!/bin/bash
              systemctl restart docker
              systemctl restart cri-docker.service
              systemctl restart kubelet
              # Add any other startup commands you need
              EOF
  tags = merge(local.common_tags, {
    Name = "k8s-control-plane"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_instance" "worker_nodes" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.kube_sg.id]
  key_name               = var.key_name
  user_data              = <<-EOF
                              #!/bin/bash
                              systemctl start containerd || systemctl start docker
                              systemctl restart kubelet
                            EOF

  tags = merge(local.common_tags, {
    Name = "k8s-worker-${count.index + 1}"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_lb" "nlb" {
  name                       = "k8s-nlb"
  internal                   = false
  load_balancer_type         = "network"
  subnets                    = [aws_subnet.main.id] # single subnet only
  enable_deletion_protection = false
  tags = {
    Name      = "k8s-nlb"
    terraform = "true"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_eip" "control_plane_eip" {
  instance = aws_instance.control_plane.id
  tags = {
    Name      = "k8s-control-plane-eip"
    terraform = "true"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_eip" "worker_node_1" {
  instance = aws_instance.worker_nodes[0].id
  tags = merge(local.common_tags, {
    Name = "k8s-worker-1-eip"
  })
}

resource "aws_eip" "worker_node_2" {
  instance = aws_instance.worker_nodes[1].id
  tags = merge(local.common_tags, {
    Name = "k8s-worker-2-eip"
  })
}

resource "kubernetes_manifest" "ccm" {
  for_each = {
    for doc in split("---", file("${path.module}/aws_ccm.yaml")) :
    "${yamldecode(doc).kind}-${yamldecode(doc).metadata.name}-${lookup(yamldecode(doc).metadata, "namespace", "default")}" => yamldecode(doc)
    if trimspace(doc) != ""
  }

  manifest = each.value

  lifecycle {
    ignore_changes = [manifest]
  }
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name
  version    = "4.10.0" # Adjust based on compatibility
  depends_on = [kubernetes_manifest.ccm]

  set = [
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "nlb"
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-cross-zone-load-balancing-enabled"
      value = "true"
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-connection-idle-timeout"
      value = "3600"
    },
    {
      name  = "controller.service.type"
      value = "LoadBalancer"
    }
  ]
}

data "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.46.7" # check for latest compatible version
  create_namespace = true

  set = [
    {
      name  = "server.service.type"
      value = "ClusterIP"
    }
  ]
}

resource "kubernetes_manifest" "argocd_ingress" {
  depends_on = [
    helm_release.nginx_ingress,
    data.kubernetes_namespace.argocd
  ]
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "argocd-server-ingress"
      namespace = "argocd"
      annotations = {
        "nginx.ingress.kubernetes.io/ssl-redirect"     = "true"
        "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
      }
    }
    spec = {
      rules = [
        {
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "argocd-server"
                    port = {
                      number = 443
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }
}

data "kubernetes_service" "nginx_ingress_controller" {
  metadata {
    name      = "nginx-ingress-ingress-nginx-controller"
    namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
  }

  depends_on = [helm_release.nginx_ingress]
}

output "nginx_ingress_lb_hostname" {
  value = data.kubernetes_service.nginx_ingress_controller.status[0].load_balancer[0].ingress[0].hostname
}

output "control_plane_eip" {
  value = aws_eip.control_plane_eip.public_ip
}

output "worker1_eip" {
  value = aws_eip.worker_node_1.public_ip
}

output "worker2_eip" {
  value = aws_eip.worker_node_2.public_ip
}

output "kubeconfig_path" {
  value = var.kubeconfig_path
}
