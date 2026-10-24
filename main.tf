locals {
  prefixo = "${var.project}-${var.environment}"
}

# --- Rede (criada pelo repositorio oficina-infra-k8s) -------------------------

data "aws_vpc" "this" {
  tags = { Name = "${local.prefixo}-vpc" }
}

data "aws_subnets" "privadas" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
  tags = { Tier = "private" }
}

# Security group do cluster EKS (pods e nos), para liberar a aplicacao no banco
data "aws_eks_cluster" "this" {
  name = "${local.prefixo}-eks"
}

# --- Security groups ----------------------------------------------------------

# Grupo "cliente do banco": quem o tiver pode abrir conexao no RDS (ex.: Lambdas de autenticacao)
resource "aws_security_group" "db_clients" {
  name        = "${local.prefixo}-db-clients"
  description = "Recursos autorizados a acessar o PostgreSQL"
  vpc_id      = data.aws_vpc.this.id

  egress {
    description = "Saida liberada (Secrets Manager via NAT, banco)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.prefixo}-db-clients" }
}

resource "aws_security_group" "db" {
  name        = "${local.prefixo}-db"
  description = "PostgreSQL: entrada somente dos clientes autorizados e do cluster EKS"
  vpc_id      = data.aws_vpc.this.id
  tags        = { Name = "${local.prefixo}-db" }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_clients" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.db_clients.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Lambdas e demais clientes autorizados"
}

resource "aws_vpc_security_group_ingress_rule" "db_from_eks" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "API da oficina rodando no EKS"
}

# --- RDS PostgreSQL -----------------------------------------------------------

resource "random_password" "db" {
  length  = 32
  special = true
  # caracteres que quebram connection strings ou URLs ficam de fora
  override_special = "!#$%*()-_=+[]{}<>?"
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.prefixo}-db"
  subnet_ids = data.aws_subnets.privadas.ids
}

resource "aws_db_parameter_group" "this" {
  name   = "${local.prefixo}-postgres16"
  family = "postgres16"

  # Log de consultas lentas: alimenta a investigacao de gargalos (CloudWatch -> New Relic)
  parameter {
    name  = "log_min_duration_statement"
    value = tostring(var.slow_query_ms)
  }

  # Exige TLS nas conexoes (a aplicacao e a Lambda conectam com SslMode=Require)
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}

resource "aws_db_instance" "this" {
  identifier     = "${local.prefixo}-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 5432

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period         = var.backup_retention_days
  enabled_cloudwatch_logs_exports = ["postgresql"]
  auto_minor_version_upgrade      = true

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${local.prefixo}-postgres-final" : null
  apply_immediately         = true
}

# --- Segredo consumido pela Lambda e pela aplicacao ----------------------------

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project}/${var.environment}/db"
  description             = "Credenciais do PostgreSQL da oficina (${var.environment})"
  recovery_window_in_days = 0 # permite recriar o ambiente sem esperar 7 dias
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.db_name
    username = var.db_username
    password = random_password.db.result
  })
}
