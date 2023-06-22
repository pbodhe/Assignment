import datetime
import re

import boto3

client = boto3.client("dynamodb")


def lambda_handler(event, context):
    # create DynamoDb table. Will error if already exists - no problem. AWS command:
    # Assume table exists - create in terraform. If it doesnt, CT will be full of errors
    # table-name: EKS_cluster_monitoring
    # partition key: cluster_name = string
    # sort_key: alert_name = string

    # Get the cluster name from the fixed format topic arn
    records = event["Records"][0]
    topic = records["Sns"]["TopicArn"]
    message = records["Sns"]["Message"]

    print("Call from SNS topic: " + topic + ", subject: ")

    m = re.search("^arn:aws:sns:.+?:\\d+?:(.+?)-PrometheusAlerts$", topic)
    if m:
        clusterName = m.group(0)
        print("Cluster name is: " + clusterName)
    else:
        raise ValueError("Unable to find cluster name in '{0}'".format(topic))

    # get alerts and their statuses
    # print("Message body is: "+message)

    currentAlertStatus = ""
    lines = message.split("\\n")

    for line in lines:
        # print("Line: '{0}'".format(line))

        alertRe = re.search("^Alerts (.+?):$", line)
        if alertRe:
            print("RE Alert found: " + alertRe.group(1))
            currentAlertStatus = alertRe.group(1)

        # now just look for the alert labels
        labelRe = re.search("^ - alertname = (.+)", line)
        if labelRe:
            currentAlertLabel = labelRe.group(1)
            print("RE Label found: {0}".format(currentAlertLabel))
            print(
                "DynamoDB update: cluster: {0}, status: {1}, label: {2}".format(
                    clusterName, currentAlertStatus, currentAlertLabel
                )
            )

            # write to dynamodb, override whatever is there
            client.put_item(
                TableName="eks_cluster_monitoring",
                Item={
                    "cluster_name": {"S": clusterName},
                    "alert_status": {"S": currentAlertStatus},
                    "alert_name": {"S": currentAlertLabel},
                    "last_updated": {
                        "S": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    },
                    "last_full_message": {"S": message},
                },
            )

    response = {
        "statusCode": 200,
        "body": "successfully created item!",
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
    }

    return response
