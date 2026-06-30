data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  state_machine_name = "${var.environment}-${var.project}-${var.name}-cron-jobs"
}

resource "aws_sfn_state_machine" "state_machine" {
  name     = local.state_machine_name
  role_arn = aws_iam_role.state_machine.arn

  definition = templatefile("${path.module}/${var.s3_trigger != null ? "cron_jobs_state_machine_with_s3.json" : "cron_jobs_state_machine.json"}", merge(
    {
      "cluster_arn" : var.ecs_cluster_arn,
      "subnets" : jsonencode(var.subnet_ids),
      "security_groups" : jsonencode(var.security_group_ids)
      "sns_topic_arn" : var.aws_sns_error_topic_arn
      "task_definition" : var.task_definition
    },
    var.s3_trigger != null ? {
      "container_name" : var.s3_trigger.container_name
    } : {}
  ))

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.state_machine.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

  lifecycle {
    precondition {
      condition     = var.schedule_expression == null || var.s3_trigger == null
      error_message = "You cannot specify both schedule_expression and s3_trigger at the same time. Choose either cron-based scheduling or S3 event triggering."
    }
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
      "${var.task_definition}*"

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

resource "aws_cloudwatch_event_rule" "cron_job" {
  count               = var.schedule_expression != null ? 1 : 0
  name                = "${local.state_machine_name}-${var.name}"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "cron_job" {
  count     = var.schedule_expression != null ? 1 : 0
  target_id = "${local.state_machine_name}-${var.name}"
  rule      = aws_cloudwatch_event_rule.cron_job[count.index].name
  arn       = aws_sfn_state_machine.state_machine.arn
  role_arn  = aws_iam_role.run_state_machine.arn
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


##########################################
# S3 TRIGGER
##########################################

# Enable EventBridge notifications on the S3 bucket
resource "aws_s3_bucket_notification" "eventbridge" {
  count  = var.s3_trigger != null ? 1 : 0
  bucket = var.s3_trigger.bucket_name

  eventbridge = true
}

resource "aws_cloudwatch_event_rule" "s3_trigger" {
  count       = var.s3_trigger != null ? 1 : 0
  name        = "${local.state_machine_name}-s3-trigger"
  description = "Trigger state machine on S3 object creation"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [var.s3_trigger.bucket_name]
      }
      object = merge(
        var.s3_trigger.filter_prefix != "" ? { key = [{ prefix = var.s3_trigger.filter_prefix }] } : {},
        var.s3_trigger.filter_suffix != "" ? { key = [{ suffix = var.s3_trigger.filter_suffix }] } : {}
      )
    }
  })
}

resource "aws_cloudwatch_event_target" "s3_trigger" {
  count     = var.s3_trigger != null ? 1 : 0
  target_id = "${local.state_machine_name}-s3-trigger"
  rule      = aws_cloudwatch_event_rule.s3_trigger[count.index].name
  arn       = aws_sfn_state_machine.state_machine.arn
  role_arn  = aws_iam_role.run_state_machine.arn

  input_transformer {
    input_paths = {
      bucket = "$.detail.bucket.name"
      key    = "$.detail.object.key"
    }
    input_template = <<-EOT
    {
      "s3Bucket": <bucket>,
      "s3Key": <key>
    }
    EOT
  }
}

# Grant ECS task role permission to read from S3 bucket
data "aws_iam_policy_document" "task_s3_read" {
  count = var.s3_trigger != null ? 1 : 0

  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket"
    ]

    resources = [
      var.s3_trigger.bucket_arn,
      "${var.s3_trigger.bucket_arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "task_s3_read" {
  count  = var.s3_trigger != null ? 1 : 0
  name   = "${local.state_machine_name}-task-s3-read"
  policy = data.aws_iam_policy_document.task_s3_read[0].json
  role   = var.s3_trigger.task_role_name
}
