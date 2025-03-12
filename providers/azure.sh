#!/bin/sh

# Validate Azure parameters
validate_azure_params() {
  if [ "${AZURE_STORAGE_ACCOUNT}" = "**None**" ]; then
    echo "You need to set the AZURE_STORAGE_ACCOUNT environment variable."
    exit 1
  fi

  if [ "${AZURE_STORAGE_KEY}" = "**None**" ]; then
    echo "You need to set the AZURE_STORAGE_KEY environment variable."
    exit 1
  fi

  if [ "${AZURE_CONTAINER}" = "**None**" ]; then
    echo "You need to set the AZURE_CONTAINER environment variable."
    exit 1
  fi

  # Set up Azure connection string
  export AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=https;AccountName=${AZURE_STORAGE_ACCOUNT};AccountKey=${AZURE_STORAGE_KEY};EndpointSuffix=core.windows.net"
}

# Set up Azure prefix
setup_provider_prefix() {
  if [ "${STORAGE_PROVIDER}" = "azure" ]; then
    if [ -z ${AZURE_PREFIX+x} ]; then
      STORAGE_PREFIX=""
    else
      STORAGE_PREFIX="${AZURE_PREFIX}/"
    fi
  fi
}

# Upload file to Azure Blob Storage
upload_to_azure() {
  local src_file="$1"
  local dest_file="$2"
  
  echo "Uploading dump to Azure container: ${AZURE_CONTAINER}"
  az storage blob upload --container-name "${AZURE_CONTAINER}" --file "${src_file}" --name "${STORAGE_PREFIX}${dest_file}" --overwrite || exit 2
}

# Download file from Azure Blob Storage
download_from_azure() {
  local src_file="$1"
  local dest_file="$2"
  
  echo "Downloading from Azure container: ${AZURE_CONTAINER}"
  az storage blob download --container-name "${AZURE_CONTAINER}" --name "${STORAGE_PREFIX}${src_file}" --file "${dest_file}" || exit 2
}

# Find latest backup in Azure Blob Storage
find_latest_backup_azure() {
  local db_pattern
  
  if [ "${POSTGRES_BACKUP_ALL}" == "true" ]; then
    db_pattern="all_"
  else
    db_pattern="${POSTGRES_DATABASE}_"
  fi
  
  az storage blob list --container-name "${AZURE_CONTAINER}" --prefix "${STORAGE_PREFIX}${db_pattern}" \
    --query "sort_by([].name, &)" -o tsv | tail -n 1
}

# Clean up old backups in Azure Blob Storage
cleanup_old_backups_azure() {
  local cutoff_date="$1"
  local db_pattern
  
  echo "Cleaning up old backups in Azure before ${cutoff_date}..."
  
  if [ "${POSTGRES_BACKUP_ALL}" == "true" ]; then
    db_pattern="all_"
  else
    db_pattern="${POSTGRES_DATABASE}_"
  fi
  
  # List blobs and filter by creation time
  az storage blob list --container-name "${AZURE_CONTAINER}" --prefix "${STORAGE_PREFIX}${db_pattern}" \
    --query "[?properties.creationTime < '${cutoff_date}'].name" -o tsv | while read -r blob; do
      if [ -n "${blob}" ]; then
        echo "Deleting old backup: ${blob}"
        az storage blob delete --container-name "${AZURE_CONTAINER}" --name "${blob}"
      fi
    done
}