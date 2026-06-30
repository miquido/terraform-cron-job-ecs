# cron-job-ecs <a href="https://miquido.com"><img align="right" src="https://cdn.miquido.dev/miquido-logo.png" width="150" /></a>

Terraform module that runs ECS tasks on a schedule or S3 trigger using AWS Step Functions

## Development

```bash
make init   # run once after cloning
make readme # regenerate README.md
make lint   # lint terraform code
```

## Usage

```hcl
module "cron_job" {
  source = "git@gitlab.miquido.com:miquido/terraform/cron-job-ecs.git?ref=X.Y.Z"

  name                   = "my-job"
  environment            = "production"
  project                = "my-project"
  aws_sns_error_topic_arn = aws_sns_topic.alerts.arn
  ecs_cluster_arn        = aws_ecs_cluster.main.arn
  task_definition        = aws_ecs_task_definition.my_task.arn
  task_role_arn          = aws_iam_role.task.arn
  task_exec_role_arn     = aws_iam_role.task_exec.arn
  subnet_ids             = module.vpc.private_subnets
  security_group_ids     = [aws_security_group.ecs.id]

  # Option 1: cron schedule
  schedule_expression = "cron(0 6 * * ? *)"

  # Option 2: S3 trigger (mutually exclusive with schedule_expression)
  # s3_trigger = {
  #   bucket_name    = aws_s3_bucket.input.id
  #   bucket_arn     = aws_s3_bucket.input.arn
  #   container_name = "my-container"
  #   filter_prefix  = "input/"
  # }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_event_rule.cron_job](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.s3_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.send_sns_on_step_function_failure](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.cron_job](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.s3_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.run_state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.run_state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.task_s3_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_s3_bucket_notification.eventbridge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [aws_sfn_state_machine.state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_sns_error_topic_arn"></a> [aws\_sns\_error\_topic\_arn](#input\_aws\_sns\_error\_topic\_arn) | n/a | `string` | n/a | yes |
| <a name="input_ecs_cluster_arn"></a> [ecs\_cluster\_arn](#input\_ecs\_cluster\_arn) | n/a | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | n/a | `string` | n/a | yes |
| <a name="input_log_retention"></a> [log\_retention](#input\_log\_retention) | n/a | `string` | `30` | no |
| <a name="input_name"></a> [name](#input\_name) | n/a | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | n/a | `string` | n/a | yes |
| <a name="input_s3_trigger"></a> [s3\_trigger](#input\_s3\_trigger) | S3 trigger configuration. If provided, will trigger the state machine on S3 object creation events. task\_role\_name is required if you want to attach S3 read permissions automatically to the ECS task role. container\_name is the name of the container in the task definition that will receive S3 environment variables. Cannot be used together with schedule\_expression. | <pre>object({<br/>    bucket_name    = string<br/>    bucket_arn     = string<br/>    filter_prefix  = optional(string, "")<br/>    filter_suffix  = optional(string, "")<br/>    task_role_name = optional(string, null)<br/>    container_name = string<br/>  })</pre> | `null` | no |
| <a name="input_schedule_expression"></a> [schedule\_expression](#input\_schedule\_expression) | Cron schedule expression for triggering the state machine. Cannot be used together with s3\_trigger. | `string` | `null` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | n/a | `list(string)` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | n/a | `list(string)` | n/a | yes |
| <a name="input_task_definition"></a> [task\_definition](#input\_task\_definition) | n/a | `string` | n/a | yes |
| <a name="input_task_exec_role_arn"></a> [task\_exec\_role\_arn](#input\_task\_exec\_role\_arn) | n/a | `string` | n/a | yes |
| <a name="input_task_role_arn"></a> [task\_role\_arn](#input\_task\_role\_arn) | n/a | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_state_machine_arn"></a> [state\_machine\_arn](#output\_state\_machine\_arn) | n/a |
<!-- END_TF_DOCS -->

## License

[MIT](LICENSE)
