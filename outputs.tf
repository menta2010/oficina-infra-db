output "db_endpoint" {
  value = aws_db_instance.this.address
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "db_secret_arn" {
  description = "Segredo JSON com host, port, dbname, username e password"
  value       = aws_secretsmanager_secret.db.arn
}

output "db_clients_security_group_id" {
  description = "Security group que libera acesso ao banco (usado pelas Lambdas)"
  value       = aws_security_group.db_clients.id
}
