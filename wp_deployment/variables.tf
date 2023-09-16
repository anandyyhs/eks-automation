variable "cluster_name" {}
variable "node_group" {}
variable "cont_image" { default = "wordpress:4.8-apache" }
variable "wp_db_host" {}
variable "wp_db_pass"{}
variable "wp_db_user"{}
variable "wp_db_name"{}
