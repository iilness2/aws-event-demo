# sqs-sns apps
resource "aws_sqs_queue" "awsevent-sqs" {
  name = "awsevent-sqs"
}

data "aws_sqs_queue" "awsevent-sqs" {
  name = "awsevent-sqs"

  depends_on = [
    "aws_sqs_queue.awsevent-sqs",
  ]
}

resource "aws_sqs_queue_policy" "awsevent-sqs-policy" {
  queue_url = "${aws_sqs_queue.awsevent-sqs.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "*",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_sns_topic.awsevent-sns.arn}"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_sns_topic" "awsevent-sns" {
  name = "awsevent-sns"
}

resource "aws_sns_topic_policy" "awsevent-sns-policy" {
  arn = "${aws_sns_topic.awsevent-sns.arn}"

  policy = <<POLICY
{
  "Version": "2008-10-17",
  "Id": "sns_policy for aws event",
  "Statement": [
    {
      "Sid": "__default_statement_ID",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": [
        "SNS:Publish",
        "SNS:RemovePermission",
        "SNS:SetTopicAttributes",
        "SNS:DeleteTopic",
        "SNS:ListSubscriptionsByTopic",
        "SNS:GetTopicAttributes",
        "SNS:Receive",
        "SNS:AddPermission",
        "SNS:Subscribe"
      ],
      "Resource": "${aws_sns_topic.awsevent-sns.arn}",
      "Condition": {
        "StringEquals": {
          "AWS:SourceOwner": "457036678279"
        }
      }
    },
    {
      "Sid": "__console_pub_0",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "SNS:Publish",
      "Resource": "${aws_sns_topic.awsevent-sns.arn}"
    }
   ]
}
POLICY
}

resource "aws_sns_topic_subscription" "awsevent-sns-sqs" {
  topic_arn = "${aws_sns_topic.awsevent-sns.arn}"
  protocol  = "sqs"
  endpoint  = "${aws_sqs_queue.awsevent-sqs.arn}"
}

# lambda for cloudwatch 
resource "aws_cloudwatch_log_group" "sns-log" {
  name = "/aws/lambda/awsevent-function"
}

resource "aws_iam_role" "sns-log-role" {
  name = "sns-log-role"
  path = "/service-role/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "sns-log-policy" {
  role = "${aws_iam_role.sns-log-role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sns:Publish"
            ],
            "Resource": "arn:aws:sns:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:ap-southeast-1:457036678279:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents",
		"logs:*"
            ],
            "Resource": [
                "arn:aws:logs:ap-southeast-1:457036678279:log-group:${aws_cloudwatch_log_group.sns-log.name}:*"
            ]
        }
    ]
}
EOF
}

resource "aws_s3_bucket" "sns-log-bucket" {
  bucket        = "sns-log-bucket-awsevent"
  force_destroy = true
}

data "template_file" "sns_yaml" {
  template = "${file("code-sns/sns.yaml")}"

  vars = {
    monitor_role = "${aws_iam_role.sns-log-role.arn}"
    sns_topic_1  = "${aws_sns_topic.awsevent-sns.arn}"
  }
}

resource "null_resource" "sns-package-awsevent" {
  provisioner "local-exec" {
    command = "echo '${ data.template_file.sns_yaml.rendered }' > code-sns/sns-temp.yaml; sam package   --template-file code-sns/sns-temp.yaml   --output-template-file code-sns/package.yml   --s3-bucket ${aws_s3_bucket.sns-log-bucket.bucket}"
  }

  depends_on = [
    "aws_iam_role.sns-log-role",
  ]
}

resource "null_resource" "sns-monitor-awsevent" {
  provisioner "local-exec" {
    command = "sam deploy --template-file code-sns/package.yml --stack-name snsmonitor-awsevent --capabilities CAPABILITY_IAM --region ap-southeast-1; rm -rf code-sns/package.yml; rm -rf code-sns/sns-temp.yaml"
  }

  depends_on = [
    "null_resource.sns-package-awsevent",
  ]
}

resource "aws_lambda_permission" "lambda_with_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = "awsevent-function"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.awsevent-sns.arn}"
}

# create lambda for monitoring
resource "aws_cloudwatch_log_group" "cw-monitor" {
  name = "/aws/clodwatch-monitor"
}

resource "aws_iam_role" "cw-monitor-role" {
  name = "cw-monitor-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "cw-monitor-policy" {
  role = "${aws_iam_role.cw-monitor-role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        }
    ]
}
EOF
}

resource "aws_s3_bucket" "cw-monitor-bucket" {
  bucket        = "cw-monitor-bucket-awsevent"
  force_destroy = true
}

data "template_file" "messagelog_yaml" {
  template = "${file("code-lambda/lambda.yaml")}"

  vars = {
    monitor_role = "${aws_iam_role.cw-monitor-role.arn}"
    loggroup_name = "${aws_cloudwatch_log_group.sns-log.name}"
  }
}

resource "null_resource" "cw-monitor-package-awsevent" {
  provisioner "local-exec" {
    command = "echo '${ data.template_file.messagelog_yaml.rendered }' > code-lambda/cw.yaml; sam package   --template-file code-lambda/cw.yaml   --output-template-file code-lambda/package.yml   --s3-bucket ${aws_s3_bucket.cw-monitor-bucket.bucket}"
  }

  depends_on = [
    "aws_iam_role.cw-monitor-role",
  ]
}

resource "null_resource" "cw-monitor-awsevent" {
  provisioner "local-exec" {
    command = "sam deploy --template-file code-lambda/package.yml --stack-name cwmonitor-awsevent --capabilities CAPABILITY_IAM --region ap-southeast-1; rm -rf code-lambda/package.yml; rm -rf code-lambda/cw.yaml"
  }

  depends_on = [
    "null_resource.cw-monitor-package-awsevent",
  ]
}
