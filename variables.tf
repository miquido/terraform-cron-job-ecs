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

variable "s3_trigger" {
  type = object({
    enabled        = bool
    bucket_name    = string
    bucket_arn     = string
    filter_prefix  = optional(string, "")
    filter_suffix  = optional(string, "")
    task_role_name = optional(string, null)
  })
  default     = null
  description = "S3 trigger configuration. If provided, will trigger the state machine on S3 object creation events. task_role_name is required if you want to attach S3 read permissions automatically to the ECS task role."
}
