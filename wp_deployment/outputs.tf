output "wordpress_hostname" {
  value = kubernetes_service.wordpress_service.load_balancer_ingress.0.hostname
}