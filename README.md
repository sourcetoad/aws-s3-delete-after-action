# AWS S3 Delete Older Action
_To delete files from S3 older than a specified time frame._

### How it works

* Give the action a delete phrase compatible with the `date` command, such as `-30 days`.
* Action requests a list of all files in the bucket filtering the response with that criteria.
* Action chunks those files in sets of 50 issuing a delete request for each set if `no_dry_run` is set to `true`.

## Usage

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v1
  with:
    role-to-assume: arn:aws:iam::123456789100:role/my-github-actions-role
    aws-region: us-east-1

- name: S3 Delete After Deploy
  uses: sourcetoad/aws-s3-delete-after-action@v1
  with:
    s3_bucket_name: bucket
    s3_prefix: prefix/
    s3_delete_phrase: "-30 days"
    no_dry_run: false
```

## Customizing

### inputs

Following inputs can be used as `step.with` keys

| Name               | Required | Type   | Description                                          |
|--------------------|----------|--------|------------------------------------------------------|
| `s3_bucket_name`   | yes      | string | S3 Bucket Name                                       |
| `s3_prefix`        | no       | string | S3 Filter Path (default: `''`)                       |
| `s3_delete_phrase` | yes      | string | Delete Phrase, commonly like `-30 days` or `-1 hour` |
| `aws_region`       | no       | string | AWS Region (default: `us-east-1`)                    |
| `no_dry_run`       | no       | string | Whether to actually delete files, (default: `false`) |

## IAM Policies
_An example hardened policy for the Role to assume with explanations._

```json5
{
    "Version": "2012-10-17",
    "Statement": [
        // Allows Action to delete objects in the specified prefix
        {
            "Effect": "Allow",
            "Action": [
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::{bucket}/{prefix}/*",
            ]
        },
        // Allows Action to list the bucket, a limitation of the AWS API
        {
            "Sid": "Stmt1435764897",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::{bucket}"
            ]
        }
    ]
}
```
