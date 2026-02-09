#!/usr/bin/env python3
import boto3
from datetime import datetime, timezone, timedelta

# This is a battlefield map in one command.
# Reason why this script is relevant to your career.
# For: On-call engineers to automate triage: reduce time-to-context, not just time-to-click.
# This is a CloudWatch alarm triage tool that summarizes alarm states and recent transitions,
#  so responders immediately know what's broken and when it started."

cw = boto3.client("cloudwatch")

def main():
    resp = cw.describe_alarms(StateValue="ALARM", MaxRecords=50)
    alarms = resp.get("MetricAlarms", [])
    print(f"\nActive alarms: {len(alarms)}\n")

    for a in alarms:
        print(f"- {a['AlarmName']}")
        print(f"  Metric: {a.get('Namespace')} {a.get('MetricName')} {a.get('Statistic')}")
        print(f"  Reason: {a.get('StateReason','')[:160]}")
        print(f"  Updated: {a.get('StateUpdatedTimestamp')}\n")

if __name__ == "__main__":
    main()
