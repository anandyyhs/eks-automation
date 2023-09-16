    #DB SUBNET GROUP

resource "aws_db_subnet_group" "db_subnet" {
  name       = "rds_subnets"
  subnet_ids = var.subnets
  tags = {
    Name = "My DB subnet group"
  }
}

		#SECURITY GROUP FOR RDS

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow mysql"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_tls"
  }
}

resource "aws_security_group_rule" "inbound" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  security_group_id = aws_security_group.rds_sg.id
  source_security_group_id  = var.sg_id
}


		#CREATE RDS DB

resource "aws_db_instance" "rds_db" {
  depends_on = [ var.subnets , var.vpc_id, var.sg_id ]
  allocated_storage    = 20
  identifier = "database-wp"
  db_subnet_group_name =  aws_db_subnet_group.db_subnet.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  port = "3306"
  storage_type         = "gp2"
  publicly_accessible = false
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "mysql_wp_db"
  username             = "admin"
  password             = var.db_password
  parameter_group_name = "default.mysql5.7"
}

