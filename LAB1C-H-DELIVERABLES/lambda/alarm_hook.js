const {
  CloudWatchLogsClient,
  StartQueryCommand,
  GetQueryResultsCommand,
} = require("@aws-sdk/client-cloudwatch-logs");
const {
  SSMClient,
  GetParameterCommand,
  StartAutomationExecutionCommand,
} = require("@aws-sdk/client-ssm");
const {
  SecretsManagerClient,
  GetSecretValueCommand,
} = require("@aws-sdk/client-secrets-manager");
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const {
  BedrockRuntimeClient,
  InvokeModelCommand,
} = require("@aws-sdk/client-bedrock-runtime");

const logsClient = new CloudWatchLogsClient({});
const ssmClient = new SSMClient({});
const secretsClient = new SecretsManagerClient({});
const s3Client = new S3Client({});
const bedrockClient = new BedrockRuntimeClient({});

async function runLogsInsightsQuery(logGroupName, queryString, startTime, endTime) {
  const start = await logsClient.send(
    new StartQueryCommand({
      logGroupName,
      startTime,
      endTime,
      queryString,
      limit: 100,
    })
  );
  const queryId = start.queryId;
  if (!queryId) {
    throw new Error("StartQuery did not return a queryId");
  }
  for (let i = 0; i < 20; i += 1) {
    const res = await logsClient.send(new GetQueryResultsCommand({ queryId }));
    if (res.status === "Complete") {
      return res.results || [];
    }
    await new Promise((r) => setTimeout(r, 1500));
  }
  return [];
}

exports.handler = async (event) => {
  console.log("CloudWatch alarm event:", JSON.stringify(event, null, 2));

  const now = Math.floor(Date.now() / 1000);
  const startTime = now - 3600;
  const endTime = now;

  const logGroupName = process.env.LOG_GROUP_NAME;
  const logsInsightsQuery = process.env.LOGS_INSIGHTS_QUERY;
  const ssmParamName = process.env.SSM_PARAM_NAME;
  const secretId = process.env.SECRET_ID;
  const reportBucket = process.env.REPORTS_BUCKET;
  const bedrockModelId = process.env.BEDROCK_MODEL_ID;
  const automationDocumentName = process.env.AUTOMATION_DOCUMENT_NAME;
  const automationParametersJson = process.env.AUTOMATION_PARAMETERS_JSON;
  const alarmAsgName = process.env.ALARM_ASG_NAME;

  const logsResults = logGroupName && logsInsightsQuery
    ? await runLogsInsightsQuery(logGroupName, logsInsightsQuery, startTime, endTime)
    : [];

  const ssmParam = ssmParamName
    ? await ssmClient.send(new GetParameterCommand({ Name: ssmParamName, WithDecryption: true }))
    : null;

  const secretValue = secretId
    ? await secretsClient.send(new GetSecretValueCommand({ SecretId: secretId }))
    : null;

  const alarm = event?.Records?.[0]?.Sns?.Message
    ? JSON.parse(event.Records[0].Sns.Message)
    : event;

  const prompt = [
    "Generate a short incident report summary for this CloudWatch alarm event.",
    "Include: alarm name/state, likely impact, and immediate checks.",
    "Alarm:",
    JSON.stringify(alarm, null, 2),
    "Logs Insights Results:",
    JSON.stringify(logsResults, null, 2),
  ].join("\n\n");

  let bedrockResponseText = "Bedrock response not requested or model not configured.";
  if (bedrockModelId) {
    const br = await bedrockClient.send(
      new InvokeModelCommand({
        modelId: bedrockModelId,
        contentType: "application/json",
        accept: "application/json",
        body: JSON.stringify({
          inputText: prompt,
        }),
      })
    );
    bedrockResponseText = br.body ? Buffer.from(br.body).toString("utf8") : "";
  }

  const report = {
    generatedAt: new Date().toISOString(),
    alarm,
    logsResults,
    ssmParam,
    secretMetadata: secretValue
      ? {
          arn: secretValue.ARN,
          name: secretValue.Name,
          versionId: secretValue.VersionId,
        }
      : null,
    bedrockSummary: bedrockResponseText,
  };

  const reportKey = `reports/alarm-${Date.now()}.json`;
  const markdownKey = `reports/alarm-${Date.now()}.md`;

  if (reportBucket) {
    await s3Client.send(
      new PutObjectCommand({
        Bucket: reportBucket,
        Key: reportKey,
        Body: JSON.stringify(report, null, 2),
        ContentType: "application/json",
      })
    );

    await s3Client.send(
      new PutObjectCommand({
        Bucket: reportBucket,
        Key: markdownKey,
        Body: [
          "# Alarm Report",
          `- Generated: ${report.generatedAt}`,
          `- Alarm: ${alarm?.AlarmName || "unknown"}`,
          "",
          "## Summary",
          "```\n" + bedrockResponseText + "\n```",
        ].join("\n"),
        ContentType: "text/markdown",
      })
    );
  }

  if (automationDocumentName) {
    let parameters = {};
    if (automationParametersJson) {
      parameters = JSON.parse(automationParametersJson);
    } else {
      parameters = {
        IncidentId: [String(Date.now())],
        AlarmName: [alarm?.AlarmName || "unknown"],
        ReportBucket: [reportBucket || ""],
        ReportJsonKey: [reportKey],
        ReportMarkdownKey: [markdownKey],
      };
      if (alarmAsgName) {
        parameters.AsgName = [alarmAsgName];
      }
    }
    await ssmClient.send(
      new StartAutomationExecutionCommand({
        DocumentName: automationDocumentName,
        Parameters: parameters,
      })
    );
  }

  return { ok: true, reportKey, markdownKey };
};
