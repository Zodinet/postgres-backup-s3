# PostgreSQL Backup with Multi-Provider Support

This project provides Docker images to periodically back up a PostgreSQL database to either AWS S3 or Azure Blob Storage, and to restore from the backup as needed.

## Supported Storage Providers

- **AWS S3**: The original storage provider, including support for S3-compatible services
- **Azure Blob Storage**: Added support for Microsoft Azure's blob storage service

## Usage

### Configuration

First, choose your storage provider by setting the `STORAGE_PROVIDER` environment variable:
- `s3` for AWS S3 (default)
- `azure` for Azure Blob Storage

Then configure the provider-specific environment variables.

### Docker Compose Example

```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password

  backup:
    image: zodinettech/postgres-backup-s3:16
    environment:
      # Common settings
      STORAGE_PROVIDER: s3  # or 'azure'
      SCHEDULE: '@weekly'
      BACKUP_KEEP_DAYS: 7
      ENCRYPTION_PASSWORD: passphrase  # optional
      
      # PostgreSQL settings
      POSTGRES_HOST: postgres
      POSTGRES_DATABASE: dbname
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      
      # S3-specific settings (if STORAGE_PROVIDER=s3)
      S3_REGION: us-west-1
      S3_ACCESS_KEY_ID: your-access-key
      S3_SECRET_ACCESS_KEY: your-secret-key
      S3_BUCKET: your-bucket
      S3_PREFIX: backups
      
      # Azure-specific settings (if STORAGE_PROVIDER=azure)
      AZURE_STORAGE_ACCOUNT: your-account
      AZURE_STORAGE_KEY: your-key
      AZURE_CONTAINER: your-container
      AZURE_PREFIX: backups
```

### Backup

- The `SCHEDULE` variable determines backup frequency using cron syntax. Omit to run backup immediately and exit.
- If `ENCRYPTION_PASSWORD` is provided, the backup will be encrypted using OpenSSL AES-256-CBC encryption.
- Run `docker exec <container name> sh backup.sh` to trigger a backup ad-hoc.
- If `BACKUP_KEEP_DAYS` is set, backups older than this many days will be deleted.

### Restore

> **WARNING:** DATA LOSS! All database objects will be dropped and re-created.

#### ... from latest backup
```sh
docker exec <container name> sh restore.sh
```

#### ... from specific backup
```sh
docker exec <container name> sh restore.sh <timestamp>
```

## Environment Variables

### Common Variables
- `STORAGE_PROVIDER`: Storage provider to use (`s3` or `azure`, defaults to `s3`)
- `POSTGRES_HOST`: PostgreSQL server hostname
- `POSTGRES_PORT`: PostgreSQL server port (default: 5432)
- `POSTGRES_USER`: PostgreSQL username
- `POSTGRES_PASSWORD`: PostgreSQL password
- `POSTGRES_DATABASE`: PostgreSQL database name
- `POSTGRES_BACKUP_ALL`: Set to "true" to backup all databases
- `POSTGRES_EXTRA_OPTS`: Additional options for pg_dump
- `BACKUP_FILE_NAME`: Custom filename for the backup
- `SCHEDULE`: Cron schedule for automatic backups
- `ENCRYPTION_PASSWORD`: Password for backup encryption
- `BACKUP_KEEP_DAYS`: Number of days to keep backups before deletion

### S3-specific Variables
- `S3_ACCESS_KEY_ID`: AWS access key
- `S3_SECRET_ACCESS_KEY`: AWS secret key
- `S3_BUCKET`: S3 bucket name
- `S3_PREFIX`: Prefix for backup files in S3
- `S3_REGION`: AWS region (default: us-west-1)
- `S3_ENDPOINT`: Custom endpoint for S3-compatible services
- `S3_S3V4`: Set to "yes" to use signature version 4

### Azure-specific Variables
- `AZURE_STORAGE_ACCOUNT`: Azure Storage account name
- `AZURE_STORAGE_KEY`: Azure Storage account key
- `AZURE_CONTAINER`: Azure Storage container name
- `AZURE_PREFIX`: Prefix for backup files in Azure Blob Storage

## Development

### Build the image locally

```sh
DOCKER_BUILDKIT=1 docker build --build-arg ALPINE_VERSION=3.20 .
```

### Run a simple test environment with Docker Compose

```sh
cp template.env .env
# fill out your secrets/params in .env
docker compose up -d
```

## Features

- Support for multiple storage providers (AWS S3, Azure Blob Storage)
- Automated, scheduled backups
- Encrypted backups
- Automatic cleanup of old backups
- Support for multiple PostgreSQL versions
- Backup of specific databases or all databases
- Restore capability from any backup