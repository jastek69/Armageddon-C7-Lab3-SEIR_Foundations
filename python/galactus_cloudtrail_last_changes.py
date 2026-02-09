#!/usr/bin/env python3
import boto3, json
from datetime import datetime, timezone, timedelta

# Galactus doesn't ask "what changed?" — he interrogates the timeline until it confesses.
# Change attribution is core to incident response and audit defense.
# This is an automated change tracking by querying CloudTrail for security/network/CDN modifications.

def lookup(region, minutes=120):
    ct = boto3.client("cloudtrail", region_name=region)
    end = datetime.now(timezone.utc)
    start = end - timedelta(minutes=minutes)

    # Filter on common change-heavy sources; students can tune EventName filters.
    resp = ct.lookup_events(
        StartTime=start, EndTime=end,
        MaxResults=50
    )
    events = []
    for e in resp.get("Events", []):
        events.append({
            "region": region,
            "time": str(e.get("EventTime")),
            "event": e.get("EventName"),
            "user": e.get("Username"),
            "source": e.get("EventSource"),
        })
    return events

def main():
    tokyo = lookup("ap-northeast-1")
    sp    = lookup("sa-east-1")
    print(json.dumps({"tokyo": tokyo, "saopaulo": sp}, indent=2))

if __name__ == "__main__":
    main()