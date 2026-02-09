# Translation Module Variables

variable "region" {
  description = "AWS region for the translation module"
  type        = string
}

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

variable "input_bucket_name" {
  description = "Name for the input S3 bucket (where original reports are uploaded)"
  type        = string
  default     = ""
}

variable "output_bucket_name" {
  description = "Name for the output S3 bucket (where translated reports are temporarily stored)"
  type        = string  
  default     = ""
}

variable "reports_bucket_name" {
  description = "Name of the main reports bucket (where final reports are stored)"
  type        = string
}

variable "reports_bucket_arn" {
  description = "ARN of the main reports bucket"
  type        = string
}

variable "source_language" {
  description = "Source language for translation (default: English)"
  type        = string
  default     = "en"
}

variable "target_language" {
  description = "Target language for translation (default: Japanese)"
  type        = string
  default     = "ja" 
}

variable "lambda_timeout" {
  description = "Timeout in seconds for the translation Lambda function"
  type        = number
  default     = 300
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
}