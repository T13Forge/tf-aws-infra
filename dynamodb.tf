resource "aws_dynamodb_table" "sent_emails" {
  name = "SentEmails"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "messageId"

  # defines which attributes exist and their types.
  attribute {
    name = "messageId"
    type = "S"
  }
}
