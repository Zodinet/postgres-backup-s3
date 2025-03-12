#!/bin/sh

# Common validation for PostgreSQL parameters
validate_postgres_params() {
  if [ "${POSTGRES_DATABASE}" = "**None**" -a "${POSTGRES_BACKUP_ALL}" != "true" ]; then
    echo "You need to set the POSTGRES_DATABASE environment variable or POSTGRES_BACKUP_ALL=true."
    exit 1
  fi

  if [ "${POSTGRES_HOST}" = "**None**" ]; then
    if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
      POSTGRES_HOST=$POSTGRES_PORT_5432_TCP_ADDR
      POSTGRES_PORT=$POSTGRES_PORT_5432_TCP_PORT
    else
      echo "You need to set the POSTGRES_HOST environment variable."
      exit 1
    fi
  fi

  if [ "${POSTGRES_USER}" = "**None**" ]; then
    echo "You need to set the POSTGRES_USER environment variable."
    exit 1
  fi

  if [ "${POSTGRES_PASSWORD}" = "**None**" ]; then
    echo "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
    exit 1
  fi

  # Export PGPASSWORD for PostgreSQL clients
  export PGPASSWORD=$POSTGRES_PASSWORD
  POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER $POSTGRES_EXTRA_OPTS"
}

# Delete old backups if BACKUP_KEEP_DAYS is set
cleanup_old_backups() {
  if [ "${BACKUP_KEEP_DAYS}" != "**None**" ] && [ -n "${BACKUP_KEEP_DAYS}" ]; then
    echo "Setting up cleanup for backups older than ${BACKUP_KEEP_DAYS} days..."
    
    # Get cutoff date in ISO format
    cutoff_date=$(date -d "${BACKUP_KEEP_DAYS} days ago" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -v-${BACKUP_KEEP_DAYS}d '+%Y-%m-%dT%H:%M:%SZ')
    
    case "${STORAGE_PROVIDER}" in
      s3)
        cleanup_old_backups_s3 "$cutoff_date"
        ;;
      azure) 
        cleanup_old_backups_azure "$cutoff_date"
        ;;
    esac
  fi
}