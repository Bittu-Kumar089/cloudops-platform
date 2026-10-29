# CloudOps Monitoring Runbook

## EC2 metrics

Basic CPU utilization is available under **CloudWatch > Metrics > EC2 > Per-Instance Metrics**.
Select the instance ID created for `cloudops-server`.

The CloudWatch Agent publishes these custom metrics in the `CloudOps` namespace:

- `mem_used_percent` with dimension `InstanceId`
- `used_percent` for path `/` with dimension `InstanceId`

Allow several minutes for the first datapoints after instance creation or reboot.

## Application logs

Docker containers should use the `awslogs` driver. The deployment creates `/cloudops/application`
and starts the container with `cloudops-app` as its log stream.

```bash
docker inspect --format='{{.HostConfig.LogConfig.Type}}' cloudops-app
docker logs cloudops-app
```

## CloudWatch dashboard

Create `CloudOps-Production-Demo` and add:

1. EC2 CPU utilization.
2. Custom `mem_used_percent`.
3. Custom root disk `used_percent`.
4. A logs widget for `/cloudops/application`.

Use the CloudOps instance ID in every dimension.

## Alarm and notifications

Terraform creates `cloudops-high-cpu` with a 300-second period, one evaluation, and a 70 percent
threshold. Until enough datapoints exist, the alarm can remain `INSUFFICIENT_DATA`.

Create an SNS topic, confirm an email subscription, and add the topic ARN to the alarm in the
AWS console if email notifications are required.

## Troubleshooting

```bash
sudo systemctl status amazon-cloudwatch-agent
sudo tail -n 100 /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
aws sts get-caller-identity
```

Verify that the EC2 instance profile can call CloudWatch Logs and CloudWatch put-metric-data APIs,
and verify the security group, DNS, and outbound access.
