#! /bin/sh

# exit if a command fails
set -eo pipefail

apk update

# Install common dependencies
apk add --no-cache openssl postgresql-client curl bash make py-pip

# Install AWS CLI for S3
apk add --no-cache aws-cli

apk add --virtual=build gcc libffi-dev musl-dev openssl-dev python2-dev

pip install azure-cli

apk del --purge build

# Install go-cron for scheduled backups
curl -L https://github.com/ivoronin/go-cron/releases/download/v0.0.5/go-cron_0.0.5_linux_${TARGETARCH}.tar.gz -O
tar xvf go-cron_0.0.5_linux_${TARGETARCH}.tar.gz
rm go-cron_0.0.5_linux_${TARGETARCH}.tar.gz
mv go-cron /usr/local/bin/go-cron
chmod u+x /usr/local/bin/go-cron

# Cleanup
rm -rf /var/cache/apk/*