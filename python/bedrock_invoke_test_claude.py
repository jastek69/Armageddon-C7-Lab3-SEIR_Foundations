import os
import boto3
import json
from botocore.exceptions import ClientError

region = os.environ.get("AWS_REGION", "us-east-1")
client = boto3.client("bedrock-runtime", region_name=region)

model_id = os.environ.get("BEDROCK_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0")
prompt = os.environ.get(
    "BEDROCK_PROMPT",
    "Describe the purpose of a 'hello world' program in one line.",
)

native_request = {
    "anthropic_version": "bedrock-2023-05-31",
    "max_tokens": 256,
    "temperature": 0.5,
    "messages": [
        {
            "role": "user",
            "content": [{"type": "text", "text": prompt}],
        }
    ],
}

try:
    response = client.invoke_model(
        modelId=model_id,
        body=json.dumps(native_request),
        contentType="application/json",
        accept="application/json",
    )
except (ClientError, Exception) as e:
    print(f"ERROR: Can't invoke '{model_id}'. Reason: {e}")
    raise SystemExit(1)

model_response = json.loads(response["body"].read())
print(model_response["content"][0]["text"])
