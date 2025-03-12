#! /bin/sh

set -eo pipefail

# Source common functions and provider-specific implementations
source ./providers/common.sh
source ./providers/s3.sh
source ./providers/azure.sh

# Validate common PostgreSQL parameters
validate_postgres_params

# Determine which storage provider to use
if [ "${STORAGE_PROVIDER}" = "**None**" ] || [ -z "${STORAGE_PROVIDER}" ]; then
  # Default to S3 for backward compatibility
  STORAGE_PROVIDER="s3"
fi

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

# Handle backup for all databases or specific ones
if [ "${POSTGRES_BACKUP_ALL}" == "true" ]; then
  SRC_FILE=dump.sql.gz
  DEST_FILE=all_$(date +"%Y-%m-%dT%H:%M:%SZ").sql.gz
  
  if [ "${BACKUP_FILE_NAME}" != "**None**" ] && [ -n "${BACKUP_FILE_NAME}" ]; then
    DEST_FILE=${BACKUP_FILE_NAME}.sql.gz
  fi

  echo "Creating dump of all databases from ${POSTGRES_HOST}..."
  pg_dumpall -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER | gzip > $SRC_FILE

  # Encrypt backup if password provided
  if [ "${ENCRYPTION_PASSWORD}" != "**None**" ] && [ -n "${ENCRYPTION_PASSWORD}" ]; then
    echo "Encrypting ${SRC_FILE}"
    openssl enc -aes-256-cbc -in $SRC_FILE -out ${SRC_FILE}.enc -k $ENCRYPTION_PASSWORD
    if [ $? != 0 ]; then
      >&2 echo "Error encrypting ${SRC_FILE}"
    fi
    rm $SRC_FILE
    SRC_FILE="${SRC_FILE}.enc"
    DEST_FILE="${DEST_FILE}.enc"
  fi

  # Upload backup using the selected provider
  case "${STORAGE_PROVIDER}" in
    s3)
      upload_to_s3 "$SRC_FILE" "$DEST_FILE"
      ;;
    azure)
      upload_to_azure "$SRC_FILE" "$DEST_FILE"
      ;;
  esac

  echo "SQL backup uploaded successfully"
  rm -rf $SRC_FILE
else
  OIFS="$IFS"
  IFS=','
  for DB in $POSTGRES_DATABASE
  do
    IFS="$OIFS"

    SRC_FILE=dump.sql.gz
    DEST_FILE=${DB}_$(date +"%Y-%m-%dT%H:%M:%SZ").sql.gz

    if [ "${BACKUP_FILE_NAME}" != "**None**" ] && [ -n "${BACKUP_FILE_NAME}" ]; then
      DEST_FILE=${BACKUP_FILE_NAME}_${DB}.sql.gz
    fi
    
    echo "Creating dump of ${DB} database from ${POSTGRES_HOST}..."
    pg_dump $POSTGRES_HOST_OPTS $DB | gzip > $SRC_FILE
    
    # Encrypt backup if password provided
    if [ "${ENCRYPTION_PASSWORD}" != "**None**" ] && [ -n "${ENCRYPTION_PASSWORD}" ]; then
      echo "Encrypting ${SRC_FILE}"
      openssl enc -aes-256-cbc -in $SRC_FILE -out ${SRC_FILE}.enc -k $ENCRYPTION_PASSWORD
      if [ $? != 0 ]; then
        >&2 echo "Error encrypting ${SRC_FILE}"
      fi
      rm $SRC_FILE
      SRC_FILE="${SRC_FILE}.enc"
      DEST_FILE="${DEST_FILE}.enc"
    fi

    # Upload backup using the selected provider
    case "${STORAGE_PROVIDER}" in
      s3)
        upload_to_s3 "$SRC_FILE" "$DEST_FILE"
        ;;
      azure)
        upload_to_azure "$SRC_FILE" "$DEST_FILE"
        ;;
    esac

    echo "SQL backup uploaded successfully"
    rm -rf $SRC_FILE
  done
fi