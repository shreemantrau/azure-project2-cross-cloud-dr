resource "aws_db_instance" "main" {
  identifier = "proj2dr-db"
  engine = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro" //free-tier eligible, equivalent to Azure SQL's smallest tier
  allocated_storage = 20 //20gb matched free tier
  db_name = "proj2drb"
  username = "pgadmin"
  password = var.rds_password
  db_subnet_group_name   = aws_db_subnet_group.main.name //refrenscing from aws-netwrok.tf
  vpc_security_group_ids = [aws_security_group.rds.id] //refrenscing from aws-netwrok.tf
  publicly_accessible    = true 
  skip_final_snapshot    = true // skips creating a backup snapshot on deletion
}