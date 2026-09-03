resource "aws_s3_bucket" "test" {
  bucket = "ctl-dev-bootstrap-test"
}

resource "aws_s3_bucket" "test2" {
  bucket = "ctl-dev-bootstrap-test2"
}