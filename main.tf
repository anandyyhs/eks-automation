		#AWS PROVIDER

provider "aws" {
	region = "ap-southeast-1"
	profile = "anandds"
}

variable "ENTER_DB_PASS"{}

      #CALL EKS MODULE

module "eks_module" {
   source = "./eks"
}

      #CALL RDS MODULE

module "rds_module"{
   //depends_on = [module.eks_module]
   source = "./rds"
   subnets = module.eks_module.subnet_ids
   vpc_id = module.eks_module.id_vpc
   sg_id = module.eks_module.id_sg
   db_password = var.ENTER_DB_PASS
}

      #CALL WORDPRESS DEPLOYMENT MODULE

module "wordpress_dep"{
   source = "./wp_deployment"
   cluster_name = module.eks_module.cluster_name
   node_group = module.eks_module.node_groupname
   wp_db_host = module.rds_module.rds_db_host
   wp_db_user = module.rds_module.rds_db_user
   wp_db_pass = var.ENTER_DB_PASS
   wp_db_name = module.rds_module.rds_db_name
}

output "wp_hostname" {
   value = module.wordpress_dep.wordpress_hostname
}

resource "null_resource" "open_in_chrome" {
depends_on = [module.wordpress_dep]
provisioner "local-exec" {
	    command = "start chrome ${module.wordpress_dep.wordpress_hostname}"
   }
}
