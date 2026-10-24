variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "oficina"
}

variable "environment" {
  description = "Ambiente: homolog ou prod"
  type        = string

  validation {
    condition     = contains(["homolog", "prod"], var.environment)
    error_message = "environment deve ser homolog ou prod."
  }
}

variable "db_name" {
  type    = string
  default = "oficina"
}

variable "db_username" {
  type    = string
  default = "oficina_app"
}

variable "engine_version" {
  description = "Versao do PostgreSQL"
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "Classe da instancia (db.t4g.micro cabe no free tier)"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Armazenamento inicial em GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Limite do autoscaling de armazenamento em GB"
  type        = number
  default     = 50
}

variable "multi_az" {
  description = "Replica sincrona em outra AZ (alta disponibilidade). Recomendado em prod; dobra o custo."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  type    = number
  default = 1
}

variable "deletion_protection" {
  description = "Impede destruir o banco por engano (ligar em prod)"
  type        = bool
  default     = false
}

variable "slow_query_ms" {
  description = "Consultas acima deste tempo vao para o log (observabilidade de performance)"
  type        = number
  default     = 500
}
