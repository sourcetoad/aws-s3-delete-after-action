#!/bin/bash
set -o pipefail

RESET_TEXT='\033[0m'
RED='\033[0;31m'
BLUE='\033[0;34m'

# Functions
function getBucketContents() {
    aws s3api list-objects-v2 \
     --bucket "$INPUT_S3_BUCKET" \
     --prefix "$INPUT_S3_PREFIX" \
     --output json \
     --query "Contents[?LastModified<='$1'].Key"
}

function deleteFileFromBucket() {
    aws s3api delete-object \
     --bucket "$INPUT_S3_BUCKET" \
     --key "$1"
}

# Validation of AWS Creds
echo -e "S3 Delete After for AWS on GitHub Actions.";
AWS_USERID=$(aws sts get-caller-identity | jq -r '.UserId')
if [ -z "$AWS_USERID" ]; then
    echo "::error::Access could not be reached to AWS. Double check aws-actions/configure-aws-credentials is properly configured."
    exit 1;
fi

# Load in values
if [ -n "$INPUT_AWS_REGION" ]; then
    export AWS_DEFAULT_REGION=$INPUT_AWS_REGION
fi

# Get the contents of the bucket
DATE=$(gdate -d "$INPUT_S3_DELETE_PHRASE" +"%Y-%m-%dT%H:%M:%S%z")

# Ensure we have a valid date
EXIT_CODE=$?
if [ "$EXIT_CODE" -ne 0 ]; then
    echo "::error::Invalid date format. Please use a valid date format. See https://www.gnu.org/software/coreutils/manual/html_node/Relative-items-in-date-strings.html for more information."
    exit 1;
fi

echo -e "${BLUE}Reviewing files older than ${RESET_TEXT}$DATE..."
RESPONSE=$(getBucketContents "$DATE")

# Iterate and delete files if needed.
echo "$RESPONSE" | jq -r '.[]?' | while read -r file; do
    if [ "$INPUT_NO_DRY_RUN" = true ]; then
        echo -e "${RED}Deleting ${RESET_TEXT}$file"
        DELETE_RESPONSE=$(deleteFileFromBucket "$file")
        echo "$DELETE_RESPONSE"
    else
        echo -e "${BLUE}Would have deleted ${RESET_TEXT}$file"
    fi
done

# Give a little summary of total.
FILE_COUNT=$(echo "$RESPONSE" | jq -r '.[]?' | wc -l | xargs)
if [ "$INPUT_NO_DRY_RUN" = true ]; then
    echo -e "Deleted ${FILE_COUNT} files"
else
    echo -e "${BLUE}Would have deleted ${RESET_TEXT}${FILE_COUNT} files"
    echo -e "Run with ${BLUE}no_dry_run: true${RESET_TEXT} to delete files."
fi
