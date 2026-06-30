output "state_machine_arn" {
  value       = aws_sfn_state_machine.state_machine.arn
  description = "ARN of the Step Functions state machine."
}