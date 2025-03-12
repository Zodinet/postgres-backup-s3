ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION}

LABEL maintainer="Your Name <your.email@example.com>"
ARG TARGETARCH

# Create provider directory
RUN mkdir -p /app/providers
WORKDIR /app

# Copy installation script and run it
COPY install.sh .
RUN sh install.sh && rm install.sh

# Environment variables for both providers and PostgreSQL
ENV STORAGE_PROVIDER s3
# PostgreSQL settings
ENV POSTGRES_DATABASE **None**
ENV POSTGRES_BACKUP_ALL **None**
ENV POSTGRES_HOST **None**
ENV POSTGRES_PORT 5432
ENV POSTGRES_USER **None**
ENV POSTGRES_PASSWORD **None**
ENV POSTGRES_EXTRA_OPTS ''
# S3 settings
ENV S3_ACCESS_KEY_ID **None**
ENV S3_SECRET_ACCESS_KEY **None**
ENV S3_BUCKET **None**
ENV S3_PREFIX **None**
ENV S3_REGION us-west-1
ENV S3_ENDPOINT **None**
ENV S3_S3V4 no
# Azure settings
ENV AZURE_STORAGE_ACCOUNT **None**
ENV AZURE_STORAGE_KEY **None**
ENV AZURE_CONTAINER **None**
ENV AZURE_PREFIX **None**
# Common settings
ENV BACKUP_FILE_NAME **None**
ENV SCHEDULE **None**
ENV ENCRYPTION_PASSWORD **None**
ENV BACKUP_KEEP_DAYS **None**

# Copy scripts
COPY providers/common.sh providers/
COPY providers/s3.sh providers/
COPY providers/azure.sh providers/
COPY run.sh .
COPY backup.sh .
COPY restore.sh .

ENTRYPOINT []
CMD ["sh", "run.sh"]