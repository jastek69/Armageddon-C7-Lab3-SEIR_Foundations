
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
