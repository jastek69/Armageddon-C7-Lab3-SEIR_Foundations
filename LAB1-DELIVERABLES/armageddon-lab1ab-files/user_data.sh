#!/bin/bash
set -e

# Log *everything* user-data does
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== user-data start ==="
date

dnf update -y

# Core runtime + debug tooling (single install)
dnf install -y \
  python3 python3-pip \
  mariadb105 nmap-ncat \
  bind-utils jq curl-minimal wget \
  iproute net-tools traceroute tcpdump telnet

# CloudWatch Agent (optional). Don't fail the whole boot if repo/package isn't available.
if dnf install -y amazon-cloudwatch-agent; then
  echo "Installed amazon-cloudwatch-agent"
else
  echo "WARN: amazon-cloudwatch-agent install failed (continuing)"
fi

python3 -m pip install --upgrade pip || true
python3 -m pip install flask pymysql boto3

mkdir -p /opt/rdsapp

echo "=== Region from IMDS ==="
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
curl -sH "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/region || true
echo

echo "=== Tool versions ==="
mysql --version || true
nc -h 2>&1 | head -n 2 || true
dig -v 2>&1 | head -n 1 || true
jq --version || true
echo

cat >/opt/rdsapp/app.py <<'PY'
import json
import os
import boto3
import pymysql
from flask import Flask, request

REGION = os.environ.get("AWS_REGION", "us-west-2")
SECRET_ID = os.environ.get("SECRET_ID", "taaops/lab/mysql")
PARAM_DB_NAME = os.environ.get("PARAM_DB_NAME", "/lab/db/name")

secrets = boto3.client("secretsmanager", region_name=REGION)
ssm = boto3.client("ssm", region_name=REGION)

def get_db_name():
    resp = ssm.get_parameter(Name=PARAM_DB_NAME, WithDecryption=True)
    return resp["Parameter"]["Value"]

def get_db_creds():
    resp = secrets.get_secret_value(SecretId=SECRET_ID)
    return json.loads(resp["SecretString"])

def get_conn():
    c = get_db_creds()
    host = c["host"]
    user = c["username"]
    password = c["password"]
    port = int(c.get("port", 3306))
    db = get_db_name()
    return pymysql.connect(
        host=host, user=user, password=password, port=port, database=db, autocommit=True
    )

app = Flask(__name__)

@app.route("/")
def home():
    return """
    <h2>EC2 → RDS Notes App</h2>
    <p>GET /init</p>
    <p>POST /add?note=hello</p>
    <p>GET /list</p>
    """

@app.route("/init")
def init_db():
    c = get_db_creds()
    host = c["host"]
    user = c["username"]
    password = c["password"]
    port = int(c.get("port", 3306))

    dbname = get_db_name()

    conn = pymysql.connect(host=host, user=user, password=password, port=port, autocommit=True)
    cur = conn.cursor()
    cur.execute(f"CREATE DATABASE IF NOT EXISTS `{dbname}`;")
    cur.execute(f"USE `{dbname}`;")
    cur.execute("""
        CREATE TABLE IF NOT EXISTS notes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            note VARCHAR(255) NOT NULL
        );
    """)
    cur.close()
    conn.close()
    return f"Initialized {dbname} + notes table."

@app.route("/add", methods=["POST", "GET"])
def add_note():
    note = request.args.get("note", "").strip()
    if not note:
        return "Missing note param. Try: /add?note=hello", 400
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("INSERT INTO notes(note) VALUES(%s);", (note,))
    cur.close()
    conn.close()
    return f"Inserted note: {note}"

@app.route("/list")
def list_notes():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, note FROM notes ORDER BY id DESC;")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    out = "<h3>Notes</h3><ul>"
    for r in rows:
        out += f"<li>{r[0]}: {r[1]}</li>"
    out += "</ul>"
    return out

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PY

cat >/etc/systemd/system/rdsapp.service <<'SERVICE'
[Unit]
Description=EC2 to RDS Notes App
After=network.target

[Service]
WorkingDirectory=/opt/rdsapp
Environment=AWS_REGION=us-west-2
Environment=SECRET_ID=taaops/lab/mysql
Environment=PARAM_DB_NAME=/lab/db/name
ExecStart=/usr/bin/python3 /opt/rdsapp/app.py
Restart=always
StandardOutput=append:/var/log/rdsapp.log
StandardError=append:/var/log/rdsapp.log

[Install]
WantedBy=multi-user.target
SERVICE


systemctl daemon-reload
systemctl enable rdsapp
systemctl restart rdsapp

echo "=== Configure CloudWatch Agent log shipping for rdsapp ==="
cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWA'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/rdsapp.log",
            "log_group_name": "/aws/ec2/rdsapp",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
CWA

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

echo "=== user-data complete ==="
