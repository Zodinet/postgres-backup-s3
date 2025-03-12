#! /bin/sh

set -eu

# Source provider files
source ./providers/common.sh
source ./providers/s3.sh
source ./providers/azure.sh

# Determine which storage provider to use
if [ "${STORAGE_PROVIDER}" = "**None**" ] || [ -z "${STORAGE_PROVIDER}" ]; then
  # Default to S3 for backward compatibility
  STORAGE_PROVIDER="s3"
fi

echo "Using storage provider: ${STORAGE_PROVIDER}"

# Validate provider-specific parameters
case "${STORAGE_PROVIDER}" in
  s3)
    validate_s3_params
    ;;
  azure)
    validate_azure_params
    ;;
  *)
    echo "Unsupported storage provider: ${STORAGE_PROVIDER}. Supported options: s3, azure"
    exit 1
    ;;
esac

# Set provider-specific prefix
setup_provider_prefix

# Clean up old backups if BACKUP_KEEP_DAYS is set
cleanup_old_backups

# Run backup now or schedule it
if [ -z "${SCHEDULE}" ]; then
  sh backup.sh
else
  exec go-cron "${SCHEDULE}" /bin/sh backup.sh
fi