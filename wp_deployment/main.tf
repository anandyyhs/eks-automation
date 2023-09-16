
		#KUBERNETES PROVIDER

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}
data "aws_eks_cluster_auth" "auth" {
  name = var.cluster_name
}
provider "kubernetes" {
  host                   =  data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  =  data.aws_eks_cluster_auth.auth.token
  load_config_file       = false
}

		#CREATE PVC FOR WORDPRESS

resource "kubernetes_persistent_volume_claim" "wordpress_pvc" {
  metadata {
    name = "pvc-wordpress"
    labels = {
	app = "wordpress"
       }
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
     }
   }
}

		#WORDPRESS DEPLOYMENT

resource "kubernetes_deployment" "wordpress_dep" {
  metadata {
    name = "wordpress"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "wordpress"
        tire = "frontend"
      }
    }
    template {
      metadata {
        labels = {
          app = "wordpress"
          tire = "frontend"
        }
      }
      spec {
        automount_service_account_token = "true"
        node_selector = {
           "eks.amazonaws.com/nodegroup"= var.node_group
           }
        container {
          image = var.cont_image
          name  = "wordpress"
          env{
            name = "WORDPRESS_DB_HOST"
            value = var.wp_db_host
          }
          env{
            name = "WORDPRESS_DB_PASSWORD"
            value = var.wp_db_pass
           }
          env{
            name = "WORDPRESS_DB_USER"
            value = var.wp_db_user
           }
          env{
            name = "WORDPRESS_DB_NAME"
            value = var.wp_db_name
           }

          port{
            container_port = 80
            name = "wordpress"
          }
          volume_mount{
		       mount_path = "/var/www/html"
		       name = "wordpress-persistent-storage"
          }
        }
        volume{
	       name= "wordpress-persistent-storage"
	       persistent_volume_claim{
	         claim_name = kubernetes_persistent_volume_claim.wordpress_pvc.metadata.0.name
         }
        }
      }
    }
  }
  depends_on = [kubernetes_persistent_volume_claim.wordpress_pvc]
}


		#WORDPRESS LOADBALENCER

resource "kubernetes_service" "wordpress_service" {
  metadata {
    name = "wordpress"
    labels = {
      app = kubernetes_deployment.wordpress_dep.metadata.0.labels.app
    }
  }
  spec {
    selector = {
      app = "wordpress"
      tire = "frontend"
    }
    port {
      port        = 80
    }
    type = "LoadBalancer"
  }
  depends_on = [kubernetes_deployment.wordpress_dep]
}



