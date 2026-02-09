#!/bin/bash
set -e

# Log *everything* user-data does
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== user-data start ==="
date

retry_pkg() {
  local cmd="$1"
  local tries=5
  local delay=10
  local i
  for i in $(seq 1 "$tries"); do
    if eval "$cmd"; then
      return 0
    fi
    echo "package install failed (attempt $i/$tries). Retrying in ${delay}s..."
    sleep "$delay"
  done
  return 1
}

retry_pkg "DEBIAN_FRONTEND=noninteractive apt-get update -y"

# Core runtime + debug tooling (single install)
retry_pkg "DEBIAN_FRONTEND=noninteractive apt-get install -y \
  python3 python3-pip python3-flask python3-pymysql python3-boto3 \
  mariadb-client netcat-openbsd \
  dnsutils jq curl wget \
  iproute2 net-tools traceroute tcpdump telnet"


mkdir -p /opt/rdsapp
mkdir -p /opt/rdsapp/static
if [ ! -f /opt/rdsapp/static/example.txt ]; then
  cat >/opt/rdsapp/static/example.txt <<'TXT'
static example v1
TXT
  # Force a stable mtime so ETag/Last-Modified are consistent across instances
  touch -t 202602070000 /opt/rdsapp/static/example.txt
fi

# Placeholder image for CloudFront cache tests. This is a 1x1 transparent PNG.
if [ ! -f /opt/rdsapp/static/placeholder.png ]; then
  base64 -d >/opt/rdsapp/static/placeholder.png <<'B64'
iVBORw0KGgoAAAANSUhEUgAAAAUAAAAHCAYAAADAp4fuAAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAJcEhZcwAACxIAAAsSAdLdfvwAAACQSURBVBhXDchdC8FQAIDh92ynsY+sjiy2SJYL
rUbyUZLm9/oj/oAbJXErjTubtcNz+Qgwtef6VFVB8S0xbB9hWLZOBkO2yxWH04XaafA/D12VxGGL
+SJFRX3kfpYS+w6xI8lqkGYXY73LqE2L4+1NEITIQiCiZKM/zwdJR9FTHq5qI8eTKfkrZ9SE8/1K
KAQ/vMUkLbooDzEAAAAASUVORK5CYII=
B64
  # Stable mtime for cache tests
  touch -t 202602070000 /opt/rdsapp/static/placeholder.png
fi


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
SECRET_ID = os.environ.get("SECRET_ID", "taaops/rds/mysql")
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

@app.route("/api/public-feed")
def public_feed():
    return {
        "status": "ok",
        "service": "tokyo-rdsapp",
        "region": REGION
    }, 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PY

cat >/etc/systemd/system/rdsapp.service <<'SERVICE'
[Unit]
Description=EC2 to RDS Notes App
After=network.target

[Service]
WorkingDirectory=/opt/rdsapp
Environment=AWS_REGION=ap-northeast-1
Environment=SECRET_ID=taaops/rds/mysql
Environment=PARAM_DB_NAME=/taaops/db/name
ExecStart=/usr/bin/python3 /opt/rdsapp/app.py
Restart=always
StandardOutput=append:/var/log/rdsapp.log
StandardError=append:/var/log/rdsapp.log

[Install]
WantedBy=multi-user.target
SERVICE

# Static assets for CloudFront cache tests
mkdir -p /opt/rdsapp/static
META_TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
HOST_FQDN=$(hostname -f)
LOCAL_IPV4=$(curl -sH "X-aws-ec2-metadata-token: $META_TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4 || true)
AZ=$(curl -sH "X-aws-ec2-metadata-token: $META_TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone || true)
INSTANCE_ID=$(curl -sH "X-aws-ec2-metadata-token: $META_TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id || true)

if [ ! -f /opt/rdsapp/static/index.html ]; then
cat >/opt/rdsapp/static/index.html <<HTML
<!DOCTYPE html>
<html>
<head>
  <title>7.0 Armageddon The Brother Hood of Evil jerMutants</title>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="https://www.w3schools.com/w3css/4/w3.css">
  <link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Raleway">
  <style>
    body,h1,h3 {font-family: "Raleway", sans-serif}
    body, html {height: 100%}
    .bgimg {
      background-image: url("https://as1.ftcdn.net/v2/jpg/05/84/83/28/1000_F_584832819_iy1VULIfcOxeLu8VdXEq2BSLdHNdqNwR.jpg");
      min-height: 100%;
      background-position: center;
      background-size: cover;
    }
    .w3-display-middle {
      background-color: rgba(0, 0, 0, 0.466);
      padding: 20px;
      border-radius: 10px;
    }
    .transparent-background {
      background-color: rgba(0, 0, 0, 0.575);
      padding: 20px;
      border-radius: 10px;
    }
    .rounded-image {
      border-radius: 25px;
    }
  </style>
</head>
<body>
  <div class="bgimg w3-display-container w3-animate-opacity w3-text-white">
    <div class="w3-display-topleft w3-padding-large w3-xlarge"></div>
    <div class="w3-display-middle w3-center">
      <iframe src="https://www.shutterstock.com/shutterstock/videos/1084391821/preview/stock-footage-back-view-of-a-girl-in-swimsuit-beautiful-dark-skinned-model-in-a-white-bikini.webm"
              width="500"
              height="270"
              style="border-radius:10px;"
              frameBorder="0"              
              allowFullScreen>
      </iframe>
      <hr class="w3-border-grey" style="margin:auto;width:40%;margin-top:15px;">
      <h3 class="w3-large w3-center" style="margin-top:15px;">        
      </h3>
    </div>
    <div class="w3-display-bottomleft w3-padding-small transparent-background outlined-text">
      <h1>"This is Class 7.0 Armageddon - Cloudfront Distribution cache check by John Sweeney"</h1>
      <h3>Team Group Co-Leader is T.I.Q.S. I am Blackneto of the Brotherhood of Evil jerMutants</h3>
      <p><b>Instance Name:</b> $HOST_FQDN</p>
      <p><b>Instance Private IP Address:</b> $LOCAL_IPV4</p>
      <p><b>Availability Zone:</b> $AZ</p>
      <p><b>Instance ID:</b> $INSTANCE_ID</p>
    </div>
  </div>
</body>
</html>
HTML
  # Force a stable mtime so ETag/Last-Modified are consistent across instances
  # NOTE: We force a fixed mtime so CloudFront cache tests are stable across instances.
# If you update static content intentionally, update the file contents and bump this timestamp (or invalidate).

  touch -t 202602070000 /opt/rdsapp/static/index.html
fi


systemctl daemon-reload
systemctl enable rdsapp
systemctl restart rdsapp

echo "=== user-data complete ==="


