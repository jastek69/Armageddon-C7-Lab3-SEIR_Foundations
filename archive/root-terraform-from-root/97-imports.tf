# rdsapp-db-errors-alarm
# Use this if Alarms already exist outside of terraform

/*
import {
  to = aws_cloudwatch_metric_alarm.rdsapp_db_errors
  id = "rdsapp-db-errors-alarm"
}

import {
  to = aws_cloudwatch_metric_alarm.asm_rotation_errors
  id = "asm-rotation-errors-alarm"
}

# AWS/RDS DatabaseConnections DBInstanceIdentifier=taaops-rds
import {
  to = aws_cloudwatch_metric_alarm.db_connections_low
  id = "AWS/RDS DatabaseConnections DBInstanceIdentifier=taaops-rds"
}
*/

