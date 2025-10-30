variable "name" {
  type = string
}

variable "aws_sns_error_topic_arn" {
  type = string
}

variable "schedule_expression" {
    type = string
    default = null
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

variable "task_definition" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "task_exec_role_arn" {
  type = string
}
