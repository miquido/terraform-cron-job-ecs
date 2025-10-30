data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  state_machine_name = "${var.environment}-${var.project}-cron-jobs"
  task_definition    = "arn:aws:ecs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:task-definition/${var.task_definition_family}"
}


resource "aws_sfn_state_machine" "state_machine" {
  name     = local.state_machine_name
  role_arn = aws_iam_role.state_machine.arn

  definition = templatefile("${path.module}/cron_jobs_state_machine.json", {
    "cluster_arn" : var.ecs_cluster_arn,
    "subnets" : jsonencode(var.subnet_ids),
    "security_groups" : jsonencode(var.security_group_ids)
    "sns_topic_arn" : var.aws_sns_error_topic_arn
    "task_definition" : local.task_definition
    "container_name" : var.ecs_container_name
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.state_machine.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

}

resource "aws_iam_role" "state_machine" {
  name               = "${local.state_machine_name}-role"
  description        = "Role used for state machine ${local.state_machine_name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role_state_machine.json
}

data "aws_iam_policy_document" "assume_role_state_machine" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "role_state_machine" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "${aws_cloudwatch_log_group.state_machine.arn}*"
    ]
  }

  statement {
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups"
    ]

    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "events:PutTargets",
      "events:DescribeRule",
      "events:PutRule"
    ]

    resources = [
      "arn:aws:events:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForECSTaskRule"
    ]
  }

  statement {
    actions = [
      "ecs:RunTask",

    ]

    resources = [
      "${local.task_definition}*"

    ]
  }

  statement {
    actions = [
      "iam:PassRole",
    ]

    resources = [
      var.task_role_arn,
      var.task_exec_role_arn,
    ]
  }

  statement {
    actions = [
      "SNS:Publish",
    ]

    resources = [
      var.aws_sns_error_topic_arn
    ]
  }
}

resource "aws_iam_role_policy" "state_machine" {
  name   = "${local.state_machine_name}-policy"
  policy = data.aws_iam_policy_document.role_state_machine.json
  role   = aws_iam_role.state_machine.id
}

resource "aws_cloudwatch_log_group" "state_machine" {
  name              = "/aws/vendedlogs/states/${local.state_machine_name}"
  retention_in_days = var.log_retention
}


resource "aws_iam_role" "run_state_machine" {
  name               = "${local.state_machine_name}-run-state-machine-role"
  description        = "Role used for launching state machine ${local.state_machine_name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role_run_state_machine.json
}

data "aws_iam_policy_document" "assume_role_run_state_machine" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "role_run_state_machine" {
  statement {
    actions = [
      "states:StartExecution"
    ]

    resources = [
      aws_sfn_state_machine.state_machine.arn
    ]
  }
}

resource "aws_iam_role_policy" "run_state_machine" {
  name   = "${local.state_machine_name}-run-state-machine-policy"
  policy = data.aws_iam_policy_document.role_run_state_machine.json
  role   = aws_iam_role.run_state_machine.id
}
#

resource "aws_cloudwatch_event_rule" "cron_job" {
  for_each            = var.cron_jobs
  name                = "${local.state_machine_name}-${each.key}"
  schedule_expression = each.value["schedule_expression"]
  is_enabled          = true
}

resource "aws_cloudwatch_event_target" "cron_job" {
  for_each  = var.cron_jobs
  target_id = "${local.state_machine_name}-${each.key}"
  rule      = aws_cloudwatch_event_rule.cron_job[each.key].name
  arn       = aws_sfn_state_machine.state_machine.arn
  role_arn  = aws_iam_role.run_state_machine.arn

  input = jsonencode({
    "commands" : each.value["commands"]
  })
}


##########################################
# NOTIFY WHEN STEP FUNCTION FAILS
##########################################

resource "aws_cloudwatch_event_rule" "send_sns_on_step_function_failure" {
  name          = "${local.state_machine_name}-step-function-failure"
  event_pattern = <<EOF
{
  "source": ["aws.states"],
  "detail-type": ["Step Functions Execution Status Change"],
  "detail": {
    "status": ["FAILED"],
    "stateMachineArn": ["${aws_sfn_state_machine.state_machine.arn}"]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "sns" {
  target_id = "${local.state_machine_name}-sns-on-failure"
  rule      = aws_cloudwatch_event_rule.send_sns_on_step_function_failure.name
  arn       = var.aws_sns_error_topic_arn
}

