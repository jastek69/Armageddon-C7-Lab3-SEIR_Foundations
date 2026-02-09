import boto3
import json

s3 = boto3.client('s3')
translate = boto3.client('translate')

def lambda_handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']

    obj = s3.get_object(Bucket=bucket, Key=key)
    data = json.loads(obj['Body'].read())

    response = translate.translate_text(
        Text=data['text'],
        SourceLanguageCode=data['source'],
        TargetLanguageCode=data['target']
    )

    result = {
        "original": data['text'],
        "translated": response['TranslatedText'],
        "source": data['source'],
        "target": data['target']
    }

    output_key = key.replace(".json", "_translated.json")

    s3.put_object(
        Bucket="out-bucket-c",  # must match your bucket name
        Key=output_key,
        Body=json.dumps(result).encode()
    )
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps({ "message": "Uploaded", "key": output_key })
    }