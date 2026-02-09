
# Incident Response Report

### Incident ID
IR-DB-2026-01-25

### Title
RDS connectivity failures caused /init endpoint errors

### Reported By
Automated log monitoring / manual review of CloudWatch Logs

### Date (UTC)
2026-01-25

### Summary
The EC2-hosted Flask application (rdsapp) experienced database connectivity failures
to the RDS instance taaops-rds, resulting in repeated HTTP 500 responses on /init.
Errors showed connection refused and timeouts. Service recovered once the DB
became reachable again.

**Severity:**
Medium (endpoint failure, limited to DB-dependent routes)

**Customer Impact:**
- /init returned HTTP 500 during the outage window.
- Database initialization and DB-backed operations were unavailable.
- No data loss observed.

**Scope:**
- Application: rdsapp (EC2)
- Database: taaops-rds (MySQL)
- Region: us-west-2

**Timeline (UTC):**
- 2026-01-25 14:35:14 — First /init error; connection refused.
- 2026-01-25 14:39:25 — /init error; connection timed out.
- 2026-01-25 14:40:48 — Continued timeouts.
- 2026-01-25 14:42:11 — /init error; connection refused.
- 2026-01-25 14:42:18 — /init succeeds (HTTP 200). Recovery observed.

Evidence (Log Excerpts)
- pymysql.err.OperationalError: (2003, "Can't connect to MySQL server on
  'taaops-rds.cfqumkgmmcja.us-west-2.rds.amazonaws.com' ([Errno 111]
  Connection refused)")
- pymysql.err.OperationalError: (2003, "Can't connect to MySQL server on
  'taaops-rds.cfqumkgmmcja.us-west-2.rds.amazonaws.com' (timed out)")
- GET /init HTTP/1.1" 500 followed by GET /init HTTP/1.1" 200

**Root Cause**
RDS instance was unavailable or not accepting connections (stopped or in a
transitional state), causing application DB connection failures.

**Detection**
Detected via application error logs in CloudWatch Logs group /aws/ec2/rdsapp.

**Mitigation / Response Actions**
- Verified error stack traces in /var/log/rdsapp.log and CloudWatch Logs.
- Confirmed DB connectivity failures in logs and HTTP 500s on /init.
- Observed recovery after DB returned to available state.

**Resolution**
DB availability restored; application recovered without restart.
Recovery used Parameter Store values and AWS Secrets Manager credential rotation.

*Parameter Store Keys Used*
- /lab/db/endpoint
- /lab/db/port
- /lab/db/name

**Post-Incident Actions**
- CloudWatch log group /aws/ec2/rdsapp configured for application logs.
- Metric filter created to emit Lab/RDSApp / RdsAppDbErrors on error logs.
- Alarm created: rdsapp-db-errors-alarm (2/3 datapoints, 1-minute period).

**Preventive / Follow-up Recommendations**
- Add application retry/backoff for transient DB failures.
- Consider production WSGI server (gunicorn/uwsgi) instead of Flask dev server.
- Ensure RDS maintenance/stop actions are coordinated with app usage.

**Status**
<span style="color: green; font-weight: bold;">Resolved</span>

**References / Resources**
- `rdsapp_cloudwatch.log`

## CloudWatch Logs Insights Query Pack (Lab 1C-Bonus-B)

**Log groups (fill in):**
- WAF log group: `aws-waf-logs--webacl01`
- App log group: `/aws/ec2/-rds-app`

**Time range:** Last 15 minutes (or match the incident window)

### A) WAF Queries (CloudWatch Logs Insights)
A1) Top actions (ALLOW/BLOCK)
```
fields @timestamp, action
| stats count() as hits by action
| sort hits desc
```

A2) Top client IPs
```
fields @timestamp, httpRequest.clientIp as clientIp
| stats count() as hits by clientIp
| sort hits desc
| limit 25
```

A3) Top requested URIs
```
fields @timestamp, httpRequest.uri as uri
| stats count() as hits by uri
| sort hits desc
| limit 25
```

A4) Blocked requests only
```
fields @timestamp, action, httpRequest.clientIp as clientIp, httpRequest.uri as uri
| filter action = "BLOCK"
| stats count() as blocks by clientIp, uri
| sort blocks desc
| limit 25
```

A5) Which WAF rule is doing the blocking?
```
fields @timestamp, action, terminatingRuleId, terminatingRuleType
| filter action = "BLOCK"
| stats count() as blocks by terminatingRuleId, terminatingRuleType
| sort blocks desc
| limit 25
```

A6) Suspicious scanners (common paths)
```
fields @timestamp, httpRequest.clientIp as clientIp, httpRequest.uri as uri
| filter uri =~ /wp-login|xmlrpc|\.env|admin|phpmyadmin|\.git|login/
| stats count() as hits by clientIp, uri
| sort hits desc
| limit 50
```

A7) Country/geo (if present in your WAF logs)
```
fields @timestamp, httpRequest.country as country
| stats count() as hits by country
| sort hits desc
| limit 25
```

### B) App Queries (EC2 app log group)
B1) Count errors over time (align with alarm window)
```
fields @timestamp, @message
| filter @message like /ERROR|Exception|Traceback|DB|timeout|refused/i
| stats count() as errors by bin(1m)
| sort bin(1m) asc
```

B2) Most recent DB failures (triage)
```
fields @timestamp, @message
| filter @message like /DB|mysql|timeout|refused|Access denied|could not connect/i
| sort @timestamp desc
| limit 50
```

B3) Creds vs network classifier
```
fields @timestamp, @message
| filter @message like /Access denied|authentication failed|timeout|refused|no route|could not connect/i
| stats count() as hits by case(
    @message like /Access denied|authentication failed/i, "Creds/Auth",
    @message like /timeout|no route/i, "Network/Route",
    @message like /refused/i, "Port/SG/ServiceRefused",
    "Other"
  )
| sort hits desc
```

B4) Structured fields (requires JSON logs)
```
fields @timestamp, level, event, reason
| filter level="ERROR"
| stats count() as n by event, reason
| sort n desc
```

### C) Correlation Mini-Workflow
1) Confirm signal timing: alarm window (last 5–15 minutes) + App B1 error spike.
2) Decide: attack vs backend failure.
   - Run WAF A1 + A6: if BLOCK spikes align with incident time → likely external pressure/scanning.
   - If WAF is quiet but app errors spike → likely backend (RDS/SG/creds).
3) If backend failure suspected: run App B2 and classify.
   - Access denied → secrets drift / wrong password.
   - Timeout → SG/routing/RDS down.
   - Then retrieve known-good values: Parameter Store `/lab/db/*` and Secrets Manager `//rds/mysql`.
4) Verify recovery: App errors return to baseline (B1), WAF blocks stabilize (A6), alarm returns to OK.
