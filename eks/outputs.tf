output "subnet_ids" {
  value = data.aws_subnet_ids.test_subnet_ids.ids
}

output "id_vpc"{
   value = aws_vpc.main.id
}

output "id_sg"{
   value = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id 
}

output "cluster_name"{
   value = aws_eks_cluster.eks_cluster.name
}

output "node_groupname"{
   value = aws_eks_node_group.node_group.node_group_name
}

