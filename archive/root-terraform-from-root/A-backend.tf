terraform {
  backend "s3" {
    bucket = "jasopsoregon-s3-logs"
    key    = "armageddonlab202042026.tfstate"
    region = "us-west-2"
  }
}
