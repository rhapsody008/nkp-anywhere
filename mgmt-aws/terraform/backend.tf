terraform {
  backend "s3" {
    bucket = "memoryarchivezy"
    key    = "mynkp/resources.tfstate"
    region = "ap-southeast-1"
  }
}