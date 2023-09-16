		#CREATE VPC

resource "aws_vpc" "main" {
  cidr_block = "192.168.0.0/16"
  enable_dns_hostnames = "true"
    tags = {
    "kubernetes.io/cluster/myeks-cluster" = "shared"
    Name = "eks_VPC"
  }
}

		#PUBLIC SUBNET 1

resource "aws_subnet" "public1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-southeast-1a"
  map_public_ip_on_launch = "true"
  tags = {
    "kubernetes.io/cluster/myeks-cluster" = "shared"
    "kubernetes.io/role/elb" = 1
  }
}

		#PUBLIC SUBNET 2

resource "aws_subnet" "public2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-southeast-1b"
  map_public_ip_on_launch = "true"
  tags = {
    "kubernetes.io/cluster/myeks-cluster" = "shared"
    "kubernetes.io/role/elb" = 1
  }
}

		#INTERNET GATEWAY FOR PUB. SUBNET

resource "aws_internet_gateway" "internet_gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "int_gw"
  }
}

		#ROUTE TABLE FOR PUBLIC SUBNET

resource "aws_route_table" "rt_public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gw.id
  }
  tags = {
    Name = "intgw_rt"
  }
}

resource "aws_route_table_association" "rt_a1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.rt_public.id
}

resource "aws_route_table_association" "rt_a2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.rt_public.id
}

       		#GET SUBNETS OF VPC

data "aws_subnet_ids" "test_subnet_ids" {
  depends_on = [ aws_route_table.rt_public ]
  vpc_id = "${aws_vpc.main.id}"
}

		#CONFIG CLUSTER ROLE

resource "aws_iam_role" "cluster_role" {
  name = "cluster-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster_role.name
}

		#CREATE EKS CLUSTER

resource "aws_eks_cluster" "eks_cluster" {
  name     = "myeks-cluster"
  role_arn = aws_iam_role.cluster_role.arn
  version = "1.16"

  vpc_config {
    endpoint_private_access = "true"
    subnet_ids = data.aws_subnet_ids.test_subnet_ids.ids
  }

  tags = {
    Name = "myeks-cluster"
  }
depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSServicePolicy,
    aws_subnet.public2,
    aws_subnet.public1
  ]
}

		#CONFIG IAM ROLE FOR NODE GROUP

resource "aws_iam_role" "node_role" {
  name = "eks-node-group"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_role.name
}
resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_role.name
}
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_role.name
}

		#CREATING KEYPAIR

resource "tls_private_key" "key1"{
	algorithm = "RSA"
}
resource "local_file" "keyfile"{
	depends_on = [tls_private_key.key1]
	content = tls_private_key.key1.private_key_pem
	filename = "webkey.pem"
}
resource "aws_key_pair" "webkey" {
  depends_on = [local_file.keyfile]
  key_name   = "webkey"
  public_key =  tls_private_key.key1.public_key_openssh
}

		#CREATE PUBLIC NODE GROUP

resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "wp_ng"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      =  [ aws_subnet.public1.id , aws_subnet.public2.id ]
  remote_access {
      ec2_ssh_key = "webkey"
}
  instance_types = [ "t2.micro"]
  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }
labels =  {
  sub = "public"
}
tags = {
 "kubernetes.io/cluster/myeks-cluster" = "owned"
 "role" = "eks nodes" 
}
  #Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  #Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_key_pair.webkey,
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}

		#UPDATE CONFIG FILE FOR EKS CLUSTER

resource "null_resource" "local_exe1" {
  depends_on = [ aws_eks_node_group.node_group]
  provisioner "local-exec" {
	    command = "aws eks update-kubeconfig --name ${aws_eks_cluster.eks_cluster.name}"
   }
}

