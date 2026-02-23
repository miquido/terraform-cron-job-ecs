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

variable "container_name" {
  type        = string
  description = "Name of the container in the task definition to run"
}

variable "task_role_name" {
  type        = string
  default     = null
  description = "Name of the ECS task role (required if s3_trigger is enabled and you want to attach S3 permissions automatically)"
}

variable "s3_trigger" {
  type = object({
    enabled       = bool
    bucket_name   = string
    bucket_arn    = string
    filter_prefix = optional(string, "")
    filter_suffix = optional(string, "")
  })
  default     = null
  description = "S3 trigger configuration. If provided, will trigger the state machine on S3 object creation events."
}
