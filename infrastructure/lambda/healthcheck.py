import os

import boto3

# Injected by Terraform (aws_lambda_function.environment) — no hardcoded ARN.
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]


def lambda_handler(event, context):
    ec2 = boto3.client("ec2")
    sns = boto3.client("sns")

    # All instances in this region.
    reservations = ec2.describe_instances()["Reservations"]
    instances = [i for r in reservations for i in r["Instances"]]

    for instance in instances:
        instance_id = instance["InstanceId"]
        state = instance["State"]["Name"]

        instance_check = None
        system_check = None
        statuses = ec2.describe_instance_status(InstanceIds=[instance_id]).get(
            "InstanceStatuses", []
        )
        if statuses:
            instance_check = statuses[0]["InstanceStatus"]["Details"][0]["Status"]
            system_check = statuses[0]["SystemStatus"]["Details"][0]["Status"]

        # Unhealthy → alarm
        if instance_check == "failed" or system_check == "failed":
            _publish(
                sns,
                f"EC2 Health Alarm: {instance_id}",
                f"Instance {instance_id} has a health issue.\n"
                f"State: {state}\nInstance check: {instance_check}\nSystem check: {system_check}",
            )
        # Stopped manually → notification
        elif state == "stopped":
            _publish(
                sns,
                f"EC2 Notification: {instance_id} is STOPPED",
                f"Instance {instance_id} was stopped.",
            )
        # Healthy and running → notification
        elif state == "running" and instance_check == "ok" and system_check == "ok":
            _publish(
                sns,
                f"EC2 Healthy: {instance_id}",
                f"Instance {instance_id} is healthy and running.",
            )


def _publish(sns, subject, message):
    sns.publish(TopicArn=SNS_TOPIC_ARN, Subject=subject, Message=message)
