#!/usr/bin/env python3
import json, sys, boto3

# same evidence, same format, every time.

# Prompt-driven summarization with guardrails is now a real ops skill (AI-assisted IR).

# This is a local harness to iterate on Bedrock prompts safely using captured evidence bundles,
#  ensuring reports are accurate, consistent, and non-leaky."

br = boto3.client("bedrock-runtime")

def main():
    if len(sys.argv) < 4:
        print("Usage: galactus_bedrock_ir_generator_local.py <model_id> <evidence.json> <template.md>")
        sys.exit(1)

    model_id, evidence_path, template_path = sys.argv[1], sys.argv[2], sys.argv[3]
    evidence = json.load(open(evidence_path))
    template = open(template_path).read()

    system = "You are an SRE. Use only evidence. If unknown, say Unknown. Do not leak secrets."
    user = f"Output MUST follow this template headings exactly:\n{template}\n\nEVIDENCE JSON:\n{json.dumps(evidence, indent=2)}"

    body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 2000,
        "temperature": 0.2,
        "system": system,
        "messages": [{"role": "user", "content": [{"type":"text","text": user}]}]
    }

    resp = br.invoke_model(
        modelId=model_id,
        contentType="application/json",
        accept="application/json",
        body=json.dumps(body)
    )
    payload = json.loads(resp["body"].read())
    out = "\n".join([p["text"] for p in payload.get("content", []) if p.get("type") == "text"])
    print(out)

if __name__ == "__main__":
    main()