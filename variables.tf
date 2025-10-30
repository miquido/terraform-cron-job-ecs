variable "aws_sns_error_topic_arn" {
  type = string
}

variable "cron_jobs" {
  type = map(object({
    commands            = list(string)
    schedule_expression = string
  }))
}

variable "log_retention" {
  type = string
  default = 30
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "ecs_cluster_arn" {
  type = string
}

variable "ecs_container_name" {
  type = string
}

variable "task_definition_family" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "task_exec_role_arn" {
  type = string
}
