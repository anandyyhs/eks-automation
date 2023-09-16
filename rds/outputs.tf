output "rds_db_user" {
  value = aws_db_instance.rds_db.username
}

output "rds_db_name" {
  value = aws_db_instance.rds_db.name
}

output "rds_db_host" {
  value = aws_db_instance.rds_db.address
}

