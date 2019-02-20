# Demo AWS Event Lambda for Monitoring 
## https://www.meetup.com/AWS-User-Group-Indonesia/events/258957429/
## Presentation: https://www.slideshare.net/andrealiaman/aws-event-user-bandung-lambda-for-monitoring
### running sns-sqs app
```terraform apply -target=aws_sqs_queue.awsevent-sqs -target=aws_sqs_queue_policy.awsevent-sqs-policy -target=aws_sns_topic.awsevent-sns -target=aws_sns_topic_policy.awsevent-sns-policy -target=aws_sns_topic_subscription.awsevent-sns-sqs```

### create log for SNS
```terraform apply -target=aws_cloudwatch_log_group.sns-log -target=aws_iam_role.sns-log-role -target=aws_iam_role_policy.sns-log-policy -target=aws_s3_bucket.sns-log-bucket -target=null_resource.sns-package-awsevent -target=null_resource.sns-monitor-awsevent```

### lambda function for process log data
```terraform apply -target=aws_iam_role.cw-monitor-role -target=aws_iam_role_policy.cw-monitor-policy -target=aws_s3_bucket.cw-monitor-bucket -target=null_resource.cw-monitor-package-awsevent -target=null_resource.cw-monitor-awsevent```

