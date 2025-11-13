resource "aws_sns_topic" "user_signup" {
  name = "user-signup-topic"
}

# The Lambda function subscribes to this SNS topic.
# 'topic_arn' specifies **which SNS topic** the subscription belongs to.
# 'endpoint' specifies **the subscriber** — in this case, the Lambda function ARN
# that will receive (be invoked with) every message published to the topic.
resource "aws_sns_topic_subscription" "lambda_sub" {
  topic_arn = aws_sns_topic.user_signup.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.email_sender.arn
}
