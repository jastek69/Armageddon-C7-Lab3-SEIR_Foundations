
#!/usr/bin/env python3
import boto3, time, json, argparse
from datetime import datetime, timezone, timedelta

# Reason why Darth Malgus would be pleased with this script.
# He enjoys watching attacks get denied at the edge—statistics are trophies.
# Reason why this script is relevant to your career.
# WAF analysis and false-positive detection are daily security operations.
# How you would talk about this script at an interview.
# "I standardized WAF triage by querying logs and producing an audit-friendly summary."

logs = boto3.client("logs")

def run(group, query, minutes):
    end = int(datetime.now(timezone.utc).timestamp())
    start = int((datetime.now(timezone.utc)-timedelta(minutes=minutes)).timestamp())
    qid = logs.start_query(logGroupName=group, startTime=start, endTime=end, queryString=query, limit=50)["queryId"]
    for _ in range(30):
        r = logs.get_query_results(queryId=qid)
        if r["status"] == "Complete":
            return [{x["field"]: x["value"] for x in row} for row in r["results"]]
        time.sleep(1)
    raise TimeoutError("Query timed out")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log-group", required=True)
    ap.add_argument("--minutes", type=int, default=30)
    args = ap.parse_args()

    actions = run(args.log_group, "stats count() as hits by action | sort hits desc", args.minutes)
    top_ips = run(args.log_group, "stats count() as hits by httpRequest.clientIp | sort hits desc | limit 10", args.minutes)
    print(json.dumps({"actions": actions, "top_ips": top_ips}, indent=2))

if __name__ == "__main__":
    main()