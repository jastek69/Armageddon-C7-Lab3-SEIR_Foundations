#!/bin/bash
# Tokyo EC2 User Data Script
# Configures instance for medical application with database and monitoring

# Variables from template
REGION="${region}"
DB_SECRET_ARN="${db_secret_arn}"
LOG_GROUP_NAME="${LOG_GROUP_NAME}"
PROJECT_NAME="${PROJECT_NAME}"

# Update system
yum update -y

# Install required packages
yum install -y \
    amazon-cloudwatch-agent \
    mysql \
    nodejs \
    npm \
    python3 \
    python3-pip \
    awslogs

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Create application directory
mkdir -p /opt/taaops-app
cd /opt/taaops-app

# Configure CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/opt/taaops-app/logs/application.log",
                        "log_group_name": "${LOG_GROUP_NAME}",
                        "log_stream_name": "{instance_id}/application",
                        "retention_in_days": 14
                    },
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "/aws/${PROJECT_NAME}-tokyo/system",
                        "log_stream_name": "{instance_id}/system",
                        "retention_in_days": 14
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "TaaOps/Tokyo",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60,
                "totalcpu": false
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Start and enable CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Create application logs directory
mkdir -p /opt/taaops-app/logs

# Create a simple medical application
cat > /opt/taaops-app/app.js << 'EOF'
const http = require('http');
const fs = require('fs');
const { exec } = require('child_process');

// Log function
function log(message) {
    const timestamp = new Date().toISOString();
    const logMessage = `[${timestamp}] ${message}\n`;
    console.log(logMessage.trim());
    fs.appendFileSync('/opt/taaops-app/logs/application.log', logMessage);
}

// Get database credentials from Secrets Manager
function getDatabaseCredentials() {
    return new Promise((resolve, reject) => {
        exec(`aws secretsmanager get-secret-value --secret-id "${DB_SECRET_ARN}" --region ${REGION} --output json`, (error, stdout) => {
            if (error) {
                reject(error);
                return;
            }
            try {
                const result = JSON.parse(stdout);
                const credentials = JSON.parse(result.SecretString);
                resolve(credentials);
            } catch (e) {
                reject(e);
            }
        });
    });
}

// Simple health check endpoint
const server = http.createServer(async (req, res) => {
    res.setHeader('Content-Type', 'application/json');
    
    if (req.url === '/health') {
        res.writeHead(200);
        res.end(JSON.stringify({
            status: 'healthy',
            region: 'tokyo',
            timestamp: new Date().toISOString(),
            service: 'medical-app'
        }));
        log('Health check accessed');
    } else if (req.url === '/db-test') {
        try {
            const dbCreds = await getDatabaseCredentials();
            res.writeHead(200);
            res.end(JSON.stringify({
                status: 'database_accessible',
                endpoint: dbCreds.endpoint,
                region: 'tokyo'
            }));
            log('Database test successful');
        } catch (error) {
            res.writeHead(500);
            res.end(JSON.stringify({
                status: 'database_error',
                error: error.message
            }));
            log(`Database test failed: ${error.message}`);
        }
    } else {
        res.writeHead(200);
        res.end(JSON.stringify({
            service: 'TaaOps Medical Application',
            region: 'Tokyo (Data Authority)',
            endpoints: ['/health', '/db-test'],
            compliance: 'APPI'
        }));
    }
});

const PORT = 80;
server.listen(PORT, () => {
    log(`Tokyo Medical Application server running on port ${PORT}`);
});
EOF

# Create systemd service for the application
cat > /etc/systemd/system/taaops-app.service << EOF
[Unit]
Description=TaaOps Medical Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/taaops-app
ExecStart=/usr/bin/node app.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=AWS_REGION=${REGION}
Environment=DB_SECRET_ARN=${DB_SECRET_ARN}

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the application
systemctl daemon-reload
systemctl enable taaops-app
systemctl start taaops-app

# Configure log rotation
cat > /etc/logrotate.d/taaops-app << EOF
/opt/taaops-app/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

log "Tokyo instance setup completed successfully"