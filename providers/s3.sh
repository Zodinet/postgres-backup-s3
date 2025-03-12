#!/bin/sh

# Validate S3 parameters
validate_s3_params() {
  if [ "${S3_ACCESS_KEY_ID}" = "**None**" ]; then
    echo "You need to set the S3_ACCESS_KEY_ID environment variable."
    exit 1
  fi

  if [ "${S3_SECRET_ACCESS_KEY}" = "**None**" ]; then
    echo "You need to set the S3_SECRET_ACCESS_KEY environment variable."
    exit 1
  fi

  if [ "${S3_BUCKET}" = "**None**" ]; then
    echo "You need to set the S3_BUCKET environment variable."
    exit 1
  fi

  # Set up AWS environment variables
  export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
  export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
  export AWS_DEFAULT_REGION=${S3_REGION:-us-west-1}
  
  # Configure S3 endpoint if specified
  if [ "${S3_ENDPOINT}" != "**None**" ] && [ -n "${S3_ENDPOINT}" ]; then
    AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
  else
    AWS_ARGS=""
  fi
  
  # Configure S3 signature version if requested
  if [ "${S3_S3V4}" = "yes" ]; then
    aws configure set default.s3.signature_version s3v4
  fi
}

# Set up S3 prefix
setup_provider_prefix() {
  if [ "${STORAGE_PROVIDER}" = "s3" ]; then
    if [ -z ${S3_PREFIX+x} ]; then
      STORAGE_PREFIX="/"
    else
      STORAGE_PREFIX="/${S3_PREFIX}/"
    fi
  fi
}

# Upload file to S3
upload_to_s3() {
  local src_file="$1"
  local dest_file="$2"
  
  echo "Uploading dump to S3 bucket: ${S3_BUCKET}"
  cat "${src_file}" | aws ${AWS_ARGS} s3 cp - "s3://${S3_BUCKET}${STORAGE_PREFIX}${dest_file}" || exit 2
}

# Download file from S3
download_from_s3() {
  local src_file="$1"
  local dest_file="$2"
  
  echo "Downloading from S3 bucket: ${S3_BUCKET}"
  aws ${AWS_ARGS} s3 cp "s3://${S3_BUCKET}${STORAGE_PREFIX}${src_file}" "${dest_file}" || exit 2
}

# Find latest backup in S3
find_latest_backup_s3() {
  local db_pattern
  
  if [ "${POSTGRES_BACKUP_ALL}" == "true" ]; then
    db_pattern="all_"
  else
    db_pattern="${POSTGRES_DATABASE}_"
  fi
  
  aws ${AWS_ARGS} s3 ls "${S3_BUCKET}${STORAGE_PREFIX}${db_pattern}" \
    | sort \
    | tail -n 1 \
    | awk '{ print $4 }'
}

# Clean up old backups in S3
cleanup_old_backups_s3() {
  local cutoff_date="$1"
  local db_pattern
  
  echo "Cleaning up old backups in S3 before ${cutoff_date}..."
  
  if [ "${POSTGRES_BACKUP_ALL}" == "true" ]; then
    db_pattern="all_"
  else
    db_pattern="${POSTGRES_DATABASE}_"
  fi
  
  # List objects and filter by date
  aws ${AWS_ARGS} s3api list-objects-v2 --bucket "${S3_BUCKET}" --prefix "${STORAGE_PREFIX}${db_pattern}" \
    --query "Contents[?LastModified<='${cutoff_date}'].Key" --output text | \
    tr '\t' '\n' | while read -r key; do
      if [ -n "${key}" ]; then
        echo "Deleting old backup: ${key}"
        aws ${AWS_ARGS} s3 rm "s3://${S3_BUCKET}/${key}"
      fi
    done
}