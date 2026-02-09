def run_logs_query(logs, log_group, query, minutes, limit=50):
    end = epoch(utc_now())
    start = epoch(utc_now() - timedelta(minutes=minutes))

    qid = logs.start_query(
        logGroupName=log_group,
        startTime=start,
        endTime=end,
        queryString=query,
        limit=limit
    )["queryId"]

    for _ in range(30):
        r = logs.get_query_results(queryId=qid)
        if r["status"] == "Complete":
            return [
                {x["field"]: x["value"] for x in row}
                for row in r.get("results", [])
            ]
        if r["status"] in ("Failed", "Cancelled", "Timeout"):
            raise RuntimeError(f"Query failed: {r['status']}")
        time.sleep(1)

    raise TimeoutError("Logs query timed out")
