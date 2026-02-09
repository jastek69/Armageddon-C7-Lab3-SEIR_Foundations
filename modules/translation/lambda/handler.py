import json
import boto3
import os
from urllib.parse import unquote_plus
from datetime import datetime
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
translate_client = boto3.client('translate')
s3_client = boto3.client('s3')

# Environment variables
INPUT_BUCKET = os.environ['INPUT_BUCKET']
OUTPUT_BUCKET = os.environ['OUTPUT_BUCKET']
REPORTS_BUCKET = os.environ['REPORTS_BUCKET']
AWS_REGION = os.environ['AWS_REGION']

def lambda_handler(event, context):
    """
    Enhanced Lambda function for incident report translation workflow:
    1. Triggered when file uploaded to input bucket
    2. Translates document content English ↔ Japanese
    3. Stores translated version in output bucket
    4. Copies both original and translated to /reports directory
    """
    
    logger.info(f"Processing event: {json.dumps(event, indent=2)}")
    
    try:
        # Process each S3 record
        for record in event['Records']:
            # Parse S3 event
            bucket_name = record['s3']['bucket']['name']
            object_key = unquote_plus(record['s3']['object']['key'])
            
            logger.info(f"Processing file: {object_key} from bucket: {bucket_name}")
            
            # Download file from input bucket
            try:
                response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
                file_content = response['Body'].read()
                
                # Determine if this is a text file or binary
                content_type = response.get('ContentType', 'text/plain')
                
                if content_type.startswith('text/') or object_key.endswith(('.txt', '.md', '.json')):
                    # Text file - can translate
                    original_text = file_content.decode('utf-8')
                    
                    # Detect source language and translate
                    translated_content = translate_document(original_text, object_key)
                    
                    # Generate output filenames
                    base_name, extension = os.path.splitext(object_key)
                    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                    
                    # Store translated version in output bucket
                    translated_key = f"{base_name}_translated_{timestamp}{extension}"
                    s3_client.put_object(
                        Bucket=OUTPUT_BUCKET,
                        Key=translated_key,
                        Body=translated_content.encode('utf-8'),
                        ContentType='text/plain; charset=utf-8',
                        Metadata={
                            'original-file': object_key,
                            'translation-timestamp': timestamp,
                            'translation-type': 'english-japanese'
                        }
                    )
                    
                    # Copy both versions to reports directory
                    copy_to_reports_directory(object_key, original_text, translated_content, timestamp)
                    
                    logger.info(f"Successfully processed translation for: {object_key}")
                    
                else:
                    # Binary file or unsupported format - copy as-is
                    logger.info(f"Unsupported file type for translation: {content_type}, copying as-is")
                    copy_binary_to_reports(object_key, file_content)
                    
            except Exception as file_error:
                logger.error(f"Error processing file {object_key}: {str(file_error)}")
                continue
                
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Translation workflow completed successfully',
                'processed_files': len(event['Records']),
                'timestamp': datetime.now().isoformat()
            })
        }
        
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'message': 'Translation workflow failed'
            })
        }

def translate_document(text, filename):
    """
    Translate document content using Amazon Translate
    Handles both English->Japanese and Japanese->English
    """
    try:
        # Detect source language
        detect_response = translate_client.translate_text(
            Text=text[:1000],  # Use first 1000 chars for detection
            SourceLanguageCode='auto',
            TargetLanguageCode='en'
        )
        
        detected_language = detect_response.get('SourceLanguageCode', 'auto')
        logger.info(f"Detected language: {detected_language} for file: {filename}")
        
        # Determine translation direction
        if detected_language == 'ja':
            # Japanese to English
            source_lang = 'ja'
            target_lang = 'en'
        else:
            # Default: English to Japanese
            source_lang = 'en'
            target_lang = 'ja'
            
        # Split text into chunks if too large (Amazon Translate has 5000 byte limit)
        max_chunk_size = 4500  # Leave buffer for UTF-8 encoding
        chunks = split_text_into_chunks(text, max_chunk_size)
        
        translated_chunks = []
        for chunk in chunks:
            try:
                translate_response = translate_client.translate_text(
                    Text=chunk,
                    SourceLanguageCode=source_lang,
                    TargetLanguageCode=target_lang
                )
                translated_chunks.append(translate_response['TranslatedText'])
                
            except Exception as chunk_error:
                logger.error(f"Error translating chunk: {str(chunk_error)}")
                translated_chunks.append(f"[Translation Error: {str(chunk_error)}]\n{chunk}")
                
        return '\n'.join(translated_chunks)
        
    except Exception as e:
        logger.error(f"Error in translate_document: {str(e)}")
        return f"Translation Error: {str(e)}\n\nOriginal Content:\n{text}"

def split_text_into_chunks(text, max_size):
    """
    Split text into chunks that respect sentence boundaries when possible
    """
    if len(text.encode('utf-8')) <= max_size:
        return [text]
        
    chunks = []
    current_chunk = ""
    
    # Split by paragraphs first
    paragraphs = text.split('\n\n')
    
    for paragraph in paragraphs:
        paragraph_bytes = len(paragraph.encode('utf-8'))
        current_bytes = len(current_chunk.encode('utf-8'))
        
        if current_bytes + paragraph_bytes <= max_size:
            if current_chunk:
                current_chunk += '\n\n' + paragraph
            else:
                current_chunk = paragraph
        else:
            if current_chunk:
                chunks.append(current_chunk)
                current_chunk = paragraph
            else:
                # Paragraph is too large, split by sentences
                sentences = paragraph.split('. ')
                temp_chunk = ""
                
                for sentence in sentences:
                    if len((temp_chunk + sentence).encode('utf-8')) <= max_size:
                        temp_chunk += sentence + '. ' if sentence != sentences[-1] else sentence
                    else:
                        if temp_chunk:
                            chunks.append(temp_chunk)
                        temp_chunk = sentence + '. ' if sentence != sentences[-1] else sentence
                        
                if temp_chunk:
                    current_chunk = temp_chunk
                    
    if current_chunk:
        chunks.append(current_chunk)
        
    return chunks

def copy_to_reports_directory(original_key, original_content, translated_content, timestamp):
    """
    Copy both English and Japanese versions to the /reports directory
    """
    try:
        base_name, extension = os.path.splitext(original_key)
        
        # Create filenames for reports directory
        english_filename = f"reports/{base_name}_english_{timestamp}{extension}"
        japanese_filename = f"reports/{base_name}_japanese_{timestamp}{extension}"
        
        # Determine which is which based on content analysis
        # Simple heuristic: if original contains more ASCII chars, likely English
        ascii_ratio = sum(1 for c in original_content if ord(c) < 128) / len(original_content)
        
        if ascii_ratio > 0.8:
            # Original is likely English
            english_content = original_content
            japanese_content = translated_content
        else:
            # Original is likely Japanese  
            japanese_content = original_content
            english_content = translated_content
            
        # Upload both versions to reports bucket
        s3_client.put_object(
            Bucket=REPORTS_BUCKET,
            Key=english_filename,
            Body=english_content.encode('utf-8'),
            ContentType='text/plain; charset=utf-8',
            Metadata={
                'language': 'english',
                'translation-timestamp': timestamp,
                'original-file': original_key
            }
        )
        
        s3_client.put_object(
            Bucket=REPORTS_BUCKET,
            Key=japanese_filename,
            Body=japanese_content.encode('utf-8'),
            ContentType='text/plain; charset=utf-8',
            Metadata={
                'language': 'japanese',
                'translation-timestamp': timestamp,
                'original-file': original_key
            }
        )
        
        logger.info(f"Successfully copied to reports: {english_filename}, {japanese_filename}")
        
    except Exception as e:
        logger.error(f"Error copying to reports directory: {str(e)}")
        raise

def copy_binary_to_reports(object_key, file_content):
    """
    Copy binary files to reports directory without translation
    """
    try:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        base_name, extension = os.path.splitext(object_key)
        reports_key = f"reports/{base_name}_{timestamp}{extension}"
        
        s3_client.put_object(
            Bucket=REPORTS_BUCKET,
            Key=reports_key,
            Body=file_content,
            Metadata={
                'original-file': object_key,
                'copy-timestamp': timestamp,
                'translation': 'not-applicable'
            }
        )
        
        logger.info(f"Successfully copied binary file to reports: {reports_key}")
        
    except Exception as e:
        logger.error(f"Error copying binary file to reports: {str(e)}")
        raise