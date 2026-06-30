variable "name" {
  type        = string
  description = "Name of the cron job. Used as part of the state machine and IAM resource names."
}

variable "aws_sns_error_topic_arn" {
  type        = string
  description = "ARN of the SNS topic to notify when the Step Functions execution fails."
}

variable "schedule_expression" {
  type        = string
  default     = null
  description = "Cron schedule expression for triggering the state machine. Cannot be used together with s3_trigger."
}

variable "log_retention" {
  type        = string
  default     = 30
  description = "Number of days to retain CloudWatch logs for the state machine."
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. staging, production). Used as part of resource names."
}

variable "project" {
  type        = string
  description = "Project name. Used as part of resource names."
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs in which the ECS task will run."
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of security group IDs to attach to the ECS task."
}

variable "ecs_cluster_arn" {
  type        = string
  description = "ARN of the ECS cluster where the task will be executed."
}

variable "task_definition" {
  type        = string
  description = "ARN of the ECS task definition to run."
}

variable "task_role_arn" {
  type        = string
  description = "ARN of the IAM role assumed by the ECS task."
}

variable "task_exec_role_arn" {
  type        = string
  description = "ARN of the ECS task execution role (used by the ECS agent to pull images and publish logs)."
}

variable "s3_trigger" {
  type = object({
    bucket_name    = string
    bucket_arn     = string
    filter_prefix  = optional(string, "")
    filter_suffix  = optional(string, "")
    task_role_name = optional(string, null)
    container_name = string
  })
  default     = null
  description = "S3 trigger configuration. If provided, will trigger the state machine on S3 object creation events. task_role_name is required if you want to attach S3 read permissions automatically to the ECS task role. container_name is the name of the container in the task definition that will receive S3 environment variables. Cannot be used together with schedule_expression."
}