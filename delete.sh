#!/bin/bash
set -o pipefail

RESET_TEXT='\033[0m'
RED='\033[0;31m'
BLUE='\033[0;34m'

# Functions
function getBucketContents() {
    aws s3api list-objects-v2 \
     --bucket "$INPUT_S3_BUCKET_NAME" \
     --prefix "$INPUT_S3_PREFIX" \
     --output text \
     --query "Contents[?LastModified<='$1'].[Key]"
}

function deleteFilesFromBucket() {
    aws s3api delete-objects \
     --bucket "$INPUT_S3_BUCKET_NAME" \
     --delete "Objects=[$1]"
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
DATE=$(date -d "$INPUT_S3_DELETE_PHRASE" +"%Y-%m-%dT%H:%M:%S%z")

# Ensure we have a valid date
EXIT_CODE=$?
if [ "$EXIT_CODE" -ne 0 ]; then
    echo "::error::Invalid date format. Please use a valid date format. See https://www.gnu.org/software/coreutils/manual/html_node/Relative-items-in-date-strings.html for more information."
    exit 1;
fi

echo -e "${BLUE}Reviewing files older than ${RESET_TEXT}$DATE..."
RESPONSE=$(getBucketContents "$DATE")

# Ignore blank lines and count total files
FILE_COUNT=$(echo "$RESPONSE" | sed '/^\s*$/d' | wc -l | xargs)

# Prepare to loop and count up to a chunk limit to batch-delete files
COUNT=0
FILES=""
for FILE in $RESPONSE; do
    # Skip empty lines
    if [ -n "$FILE" ]; then
        continue;
    fi

    FILES="$FILES {Key=$FILE},"
    (( COUNT++ ))

    # Report file that is being staged for a bulk-delete
    if [ "$INPUT_NO_DRY_RUN" = true ]; then
        echo -e "${RED}Staging for deletion: ${RESET_TEXT}$FILE"
    else
        echo -e "${BLUE}Would have deleted: ${RESET_TEXT}$FILE"
    fi

    # Delete in chunks
    if [ "$COUNT" -eq 50 ]; then
        if [ "$INPUT_NO_DRY_RUN" = true ]; then
            echo -e "${RED}Deleting ${RESET_TEXT}$COUNT files."
            DELETE_RESPONSE=$(deleteFilesFromBucket "$FILES")
            echo "$DELETE_RESPONSE"
        else
            echo -e "${BLUE}Would have deleted: ${RESET_TEXT}$COUNT files."
        fi

        # Reset chunking for next run
        FILES=""
        COUNT=0
    fi
done

# Make sure we get any stragglers
if [ "$COUNT" -gt 0 ]; then
    if [ "$INPUT_NO_DRY_RUN" = true ]; then
        echo -e "${RED}Deleting ${RESET_TEXT}$COUNT files."
        DELETE_RESPONSE=$(deleteFilesFromBucket "$FILES")
        echo "$DELETE_RESPONSE"
    else
        echo -e "${BLUE}Would have deleted: ${RESET_TEXT}$COUNT files."
    fi
fi

# Give a little summary of total.
if [ "$INPUT_NO_DRY_RUN" = true ]; then
    echo -e "Deleted in total: ${FILE_COUNT} files"
else
    echo -e "${BLUE}Would have deleted in total: ${RESET_TEXT}${FILE_COUNT} files"
    echo -e "Run with ${BLUE}no_dry_run: true${RESET_TEXT} to delete files."
fi
