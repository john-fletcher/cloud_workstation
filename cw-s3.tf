# s3 bucket
resource "aws_s3_bucket" "cw-bucket" {
  bucket                  = var.bucket_name
  acl                     = "private"
  versioning {
    enabled = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.cw-kmscmk-s3.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
  force_destroy           = true
}

# s3 block all public access to bucket
resource "aws_s3_bucket_public_access_block" "cw-bucket-pubaccessblock" {
  bucket                  = aws_s3_bucket.cw-bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# s3 objects (playbook)
resource "aws_s3_bucket_object" "cw-workstation-files" {
  for_each                = fileset("workstation/", "*")
  bucket                  = aws_s3_bucket.cw-bucket.id
  key                     = "workstation/${each.value}"
  content_base64          = base64encode(file("${path.module}/workstation/${each.value}"))
  kms_key_id              = aws_kms_key.cw-kmscmk-s3.arn
}

# s3 bucket policy (iam user and instance profile)
resource "aws_s3_bucket_policy" "cw-bucket-policy" {
  bucket                  = aws_s3_bucket.cw-bucket.id
  policy                  = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "KMS Manager",
      "Effect": "Allow",
      "Principal": {
        "AWS": ["${data.aws_iam_user.cw-kmsmanager.arn}"]
      },
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.cw-bucket.arn}",
        "${aws_s3_bucket.cw-bucket.arn}/*"
      ]
    },
    {
      "Sid": "Instance List",
      "Effect": "Allow",
      "Principal": {
        "AWS": ["${aws_iam_role.cw-instance-iam-role.arn}"]
      },
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": ["${aws_s3_bucket.cw-bucket.arn}"]
    },
    {
      "Sid": "Instance Get",
      "Effect": "Allow",
      "Principal": {
        "AWS": ["${aws_iam_role.cw-instance-iam-role.arn}"]
      },
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion"
      ],
      "Resource": ["${aws_s3_bucket.cw-bucket.arn}/*"]
    },
    {
      "Sid": "Instance Put",
      "Effect": "Allow",
      "Principal": {
        "AWS": ["${aws_iam_role.cw-instance-iam-role.arn}"]
      },
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": [
        "${aws_s3_bucket.cw-bucket.arn}/ssm/*"
      ]
    }
  ]
}
POLICY
}