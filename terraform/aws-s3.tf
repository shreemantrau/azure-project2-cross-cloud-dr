resource "aws_s3_bucket" "sync" {
  bucket = "proj2dr-sync-bucket"
  force_destroy = true
}

