#!/usr/bin/env python3
"""
RADD CLI — Ops/Sec Automation Toolkit
taaops = Terraform (builds the world)
Galactus = Python (controls the battlefield)

# Galactus hates dashboards. It wants repeatable truth in one command.

# This is exactly what on-call/SRE/SecOps engineers do: automate triage, evidence collection,
# config drift detection, and safe operational actions (like invalidations).

# This is an ops CLI that standardizes incident triage: alarms + Logs Insights evidence + drift checks,
# plus CDN correctness testing and controlled invalidations. It produces consistent, auditable outputs."
"""

import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone, timedelta

import boto3

try:
    import requests  # used only for cf-probe / cloak-test
except Exception:
    requests = None


# ---------------------------
# Shared helpers
# ---------------------------

def utc_now() -> datetime:
    return datetime.now(timezone.utc)

def epoch(dt: datetime) -> int:
    return int(dt.timestamp())

def die(msg: str, code: int = 2) -> None:
    print(f"[GALACTUS] {msg}", file=sys.stderr)
    sys.exit(code)

def require_requests():
    if requests is None:
        die("requests is required for this command. Install: pip install requests")

def pp(obj) -> str:
    return json.dumps(obj, indent=2, default=str)

def safe_print_kv_list(results):
    # Logs Insights returns list of rows; each row is list of {field,value}
    for row in results:
        kv = {x.get("field"): x.get("value") for x in row}
        print(pp(kv))


# ---------------------------
# Subcommand: triage
# ---------------------------

def cmd_triage(args):
    cw = boto3.client("cloudwatch", region_name=args.region) if args.region else boto3.client("cloudwatch")

    resp = cw.describe_alarms(StateValue=args.state, MaxRecords=args.max)
    alarms = resp.get("MetricAlarms", [])

    print(f"\n[GALACTUS] Alarm triage: state={args.state}, count={len(alarms)}\n")

    for a in alarms:
        name = a.get("AlarmName")
        metric = f"{a.get('Namespace')}::{a.get('MetricName')}::{a.get('Statistic') or a.get('ExtendedStatistic')}"
        updated = a.get("StateUpdatedTimestamp")
        reason = (a.get("StateReason") or "")[:220]

        print(f"- {name}")
        print(f"  Metric: {metric}")
        print(f"  Updated: {updated}")
        print(f"  Reason: {reason}")
        print("")

    if args.json:
        print(pp(alarms))


# ---------------------------
# Subcommand: insights
# ---------------------------

def cmd_insights(args):
    logs = boto3.client("logs", region_name=args.region) if args.region else boto3.client("logs")

    end = epoch(utc_now())
    start = epoch(utc_now() - timedelta(minutes=args.minutes))

    qid = logs.start_query(
        logGroupName=args.log_group,
        startTime=start,
        endTime=end,
        queryString=args.query,
        limit=args.limit
    )["queryId"]

    # poll
    for _ in range(args.poll_seconds):
        r = logs.get_query_results(queryId=qid)
        status = r.get("status")
        if status == "Complete":
            print(f"\n[GALACTUS] Logs Insights results ({args.log_group})\nQuery:\n{args.query}\n")
            safe_print_kv_list(r.get("results", []))
            return
        if status in ("Failed", "Cancelled", "Timeout"):
            die(f"Logs Insights query ended: {status}")
        time.sleep(1)

    die("Logs Insights query timed out")


# ---------------------------
# Subcommand: cf-probe
# ---------------------------

def cmd_cf_probe(args):
    require_requests()
    print(f"\n[GALACTUS] CloudFront cache probe: {args.url}\n")

    for i in range(args.rounds):
        r = requests.get(args.url, timeout=10, allow_redirects=False)
        print(f"[{i+1}] status={r.status_code}")
        for h in ("cache-control", "age", "x-cache", "via", "etag", "last-modified"):
            if h in r.headers:
                print(f"  {h}: {r.headers[h]}")
        if args.show_body:
            print("\n--- body (first 500 chars) ---")
            print(r.text[:500])
            print("--- end body ---\n")
        time.sleep(args.delay)


# ---------------------------
# Subcommand: cloak-test
# ---------------------------

def cmd_cloak_test(args):
    require_requests()

    def get_status(url):
        try:
            r = requests.get(url, timeout=10, allow_redirects=False)
            return r.status_code, r.headers
        except Exception as e:
            return None, {"error": str(e)}

    cf_code, _ = get_status(args.cloudfront_url)
    alb_code, alb_headers = get_status(args.alb_url)

    print("\n[GALACTUS] Origin cloaking test")
    print(f"CloudFront URL: {args.cloudfront_url} -> {cf_code}")
    print(f"ALB direct URL: {args.alb_url} -> {alb_code}")

    # Typical expected: ALB 403 due to missing secret header rule.
    if alb_code in (401, 403) and cf_code and cf_code < 500:
        print("\nPASS: ALB blocked, CloudFront allowed. Cloaking proven.")
    else:
        print("\nFAIL: Cloaking not proven.")
        if "error" in alb_headers:
            print(f"ALB request error: {alb_headers['error']}")
        print("Hint: check ALB listener rules (secret header) and SG CloudFront prefix list.")


# ---------------------------
# Subcommand: drift (SSM vs Secrets)
# ---------------------------

def cmd_drift(args):
    ssm = boto3.client("ssm", region_name=args.region) if args.region else boto3.client("ssm")
    secrets = boto3.client("secretsmanager", region_name=args.region) if args.region else boto3.client("secretsmanager")

    # Pull SSM by path
    out = {}
    token = None
    while True:
        kwargs = {"Path": args.ssm_path, "Recursive": True, "WithDecryption": True}
        if token:
            kwargs["NextToken"] = token
        r = ssm.get_parameters_by_path(**kwargs)
        for p in r.get("Parameters", []):
            out[p["Name"]] = p["Value"]
        token = r.get("NextToken")
        if not token:
            break

    sec_raw = secrets.get_secret_value(SecretId=args.secret_id)["SecretString"]
    sec = json.loads(sec_raw)

    # Never print password
    secret_meta = {k: sec.get(k) for k in ("host", "port", "dbname", "username")}
    print("\n[GALACTUS] Drift check (SSM vs Secrets meta; password not displayed)\n")
    print("SSM path:", args.ssm_path)
    print("Secret:", args.secret_id)
    print("\nSecret meta:", pp(secret_meta), "\n")

    # Map expected SSM names (students can align to their lab naming)
    checks = {
        "endpoint": (out.get(f"{args.ssm_path}endpoint"), sec.get("host")),
        "port": (out.get(f"{args.ssm_path}port"), str(sec.get("port")) if sec.get("port") is not None else None),
        "dbname": (out.get(f"{args.ssm_path}name"), sec.get("dbname")),
        "username": (out.get(f"{args.ssm_path}username"), sec.get("username")),
    }

    ok = True
    for k, (a, b) in checks.items():
        if a and b and a != b:
            ok = False
            print(f"DRIFT: {k}  SSM={a}  SECRET={b}")
        else:
            print(f"OK: {k}")

    print("\nResult:", "PASS (no drift)" if ok else "FAIL (drift detected)")


# ---------------------------
# Subcommand: bedrock-report (from evidence bundle)
# ---------------------------

INCIDENT_TEMPLATE = """# Incident Report: {{incident_id}} — {{title}}

## 1. Executive Summary
- Impact:
- Customer/User Symptoms:
- Detection Method (alarm/logs):
- Severity:
- Start Time (UTC):
- End Time (UTC):
- Duration:

## 2. Timeline (UTC)
| Time | Signal | Evidence |
|------|--------|----------|
|      | Alarm triggered | |
|      | First error seen | |
|      | Triage started | |
|      | Root cause identified | |
|      | Fix applied | |
|      | Service restored | |
|      | Alarm cleared | |

## 3. Scope and Blast Radius
- Affected components:
- Entry point (ALB / WAF / CloudFront):
- Downstream dependency (RDS):
- Regions/AZs:

## 4. Evidence Collected
### 4.1 CloudWatch Alarm
- Alarm name:
- Metric:
- Threshold:
- State changes:

### 4.2 App Logs (CloudWatch Logs Insights)
- Error rate over time (1m bins):
- Top error signatures (top 5):
- Most recent error lines (top 10):

### 4.3 WAF Logs (CloudWatch Logs Insights)
- Allow vs Block:
- Top client IPs:
- Top URIs:
- Top terminating rules:

### 4.4 Configuration Sources (for Recovery)
- Parameter Store:
- Secrets Manager:
- Notes on drift:

## 5. Root Cause Analysis
- Root cause category:
- Exact failure mechanism:
- Why it wasn’t prevented:
- Contributing factors:

## 6. Resolution
- Actions taken:
- Validation checks:
- Evidence of recovery:

## 7. Preventive Actions
- Immediate:
- Short-term:
- Long-term:

## 8. Appendix
- Key CLI commands used:
- Logs Insights queries used:
- Report generated by: Amazon Bedrock model {{model_id}}
"""

def cmd_bedrock_report(args):
    br = boto3.client("bedrock-runtime", region_name=args.region) if args.region else boto3.client("bedrock-runtime")

    evidence = json.load(open(args.evidence_json, "r", encoding="utf-8"))
    template = open(args.template, "r", encoding="utf-8").read() if args.template else INCIDENT_TEMPLATE

    system = (
        "You are an SRE generating a concise, high-signal incident report.\n"
        "Use ONLY the provided evidence. Do not invent facts.\n"
        "If evidence is missing, write 'Unknown' and recommend what to collect next.\n"
        "Never output secrets (passwords, tokens, keys).\n"
        "For each major claim, cite the evidence key path you used.\n"
    )

    user = (
        "Output MUST follow this exact template headings:\n\n"
        f"{template}\n\n"
        "EVIDENCE (JSON):\n"
        f"{json.dumps(evidence, indent=2)}\n"
    )

    # Claude-style payload (students can adapt for other model families)
    body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": args.max_tokens,
        "temperature": args.temperature,
        "system": system,
        "messages": [{"role": "user", "content": [{"type": "text", "text": user}]}],
    }

    resp = br.invoke_model(
        modelId=args.model_id,
        contentType="application/json",
        accept="application/json",
        body=json.dumps(body),
    )
    payload = json.loads(resp["body"].read())
    text = "\n".join([p.get("text", "") for p in payload.get("content", []) if p.get("type") == "text"])

    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"[MALGUS] Wrote report: {args.out}")
    else:
        print(text)


# ---------------------------
# Subcommand: invalidate (controlled CDN ops)
# ---------------------------

def cmd_invalidate(args):
    cf = boto3.client("cloudfront")

    # Guardrail: require explicit flag for wildcard.
    if any(p.strip() == "/*" for p in args.paths) and not args.allow_wildcard:
        die("Wildcard /* invalidation blocked. Use --allow-wildcard only during approved incident conditions.")

    resp = cf.create_invalidation(
        DistributionId=args.distribution_id,
        InvalidationBatch={
            "Paths": {"Quantity": len(args.paths), "Items": args.paths},
            "CallerReference": f"malgus-{int(time.time())}"
        }
    )

    inv = resp["Invalidation"]
    print("\n[GALACTUS] Invalidation created")
    print("Id:", inv["Id"])
    print("Status:", inv["Status"])
    print("Paths:", args.paths)

    if args.wait:
        while True:
            r = cf.get_invalidation(DistributionId=args.distribution_id, Id=inv["Id"])
            status = r["Invalidation"]["Status"]
            print("Status:", status)
            if status == "Completed":
                print("[GALACTUS] Invalidation completed.")
                break
            time.sleep(5)


# ---------------------------
# CLI wiring
# ---------------------------

def build_parser():
    p = argparse.ArgumentParser(prog="galactus_cli.py", description="Galactus Ops CLI (Python)")

    sub = p.add_subparsers(dest="cmd", required=True)

    # triage
    t = sub.add_parser("triage", help="Triage CloudWatch alarms")
    t.add_argument("--state", default="ALARM", choices=["ALARM", "OK", "INSUFFICIENT_DATA"])
    t.add_argument("--max", type=int, default=50)
    t.add_argument("--region", default=None)
    t.add_argument("--json", action="store_true")
    t.set_defaults(func=cmd_triage)

    # insights
    i = sub.add_parser("insights", help="Run a CloudWatch Logs Insights query")
    i.add_argument("--log-group", required=True)
    i.add_argument("--query", required=True)
    i.add_argument("--minutes", type=int, default=15)
    i.add_argument("--limit", type=int, default=25)
    i.add_argument("--poll-seconds", type=int, default=30)
    i.add_argument("--region", default=None)
    i.set_defaults(func=cmd_insights)

    # cf-probe
    c = sub.add_parser("cf-probe", help="Probe CloudFront caching headers (x-cache, age, etc.)")
    c.add_argument("url")
    c.add_argument("--rounds", type=int, default=3)
    c.add_argument("--delay", type=int, default=2)
    c.add_argument("--show-body", action="store_true")
    c.set_defaults(func=cmd_cf_probe)

    # cloak-test
    k = sub.add_parser("cloak-test", help="Verify origin cloaking (CloudFront works, ALB direct blocked)")
    k.add_argument("--cloudfront-url", required=True)
    k.add_argument("--alb-url", required=True)
    k.set_defaults(func=cmd_cloak_test)

    # drift
    d = sub.add_parser("drift", help="Check drift between SSM Parameter Store and Secrets Manager (no password output)")
    d.add_argument("--ssm-path", default="/lab/db/")
    d.add_argument("--secret-id", required=True)
    d.add_argument("--region", default=None)
    d.set_defaults(func=cmd_drift)

    # bedrock-report
    b = sub.add_parser("bedrock-report", help="Generate incident report from evidence JSON using Bedrock")
    b.add_argument("--model-id", required=True)
    b.add_argument("--evidence-json", required=True)
    b.add_argument("--template", default=None, help="Optional markdown template file; defaults to built-in template")
    b.add_argument("--max-tokens", type=int, default=2000)
    b.add_argument("--temperature", type=float, default=0.2)
    b.add_argument("--region", default=None)
    b.add_argument("--out", default=None)
    b.set_defaults(func=cmd_bedrock_report)

    # invalidate
    inv = sub.add_parser("invalidate", help="Create a controlled CloudFront invalidation")
    inv.add_argument("--distribution-id", required=True)
    inv.add_argument("--paths", nargs="+", required=True)
    inv.add_argument("--allow-wildcard", action="store_true", help="Required to allow /* invalidation")
    inv.add_argument("--wait", action="store_true")
    inv.set_defaults(func=cmd_invalidate)

    return p

def main():
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)

if __name__ == "__main__":
    main()