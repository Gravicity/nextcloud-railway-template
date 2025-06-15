#!/bin/bash
set -e

echo "🚀 Starting NextCloud Railway deployment..."

# Configure Apache for Railway's PORT
export PORT=${PORT:-80}
echo "Listen $PORT" > /etc/apache2/ports.conf
echo "✅ Apache configured for port: $PORT"

# Display configuration info
echo "📊 Database: ${POSTGRES_USER}@${POSTGRES_HOST}/${POSTGRES_DB}"
echo "🔴 Redis: ${REDIS_HOST}:${REDIS_HOST_PORT}"
echo "🌐 Trusted domains: ${NEXTCLOUD_TRUSTED_DOMAINS}"

# Pre-configure database connection for setup wizard
echo "🔧 Pre-configuring database connection..."
mkdir -p /var/www/html/config

# Create autoconfig.php to pre-fill database settings
cat > /var/www/html/config/autoconfig.php << EOF
<?php
\$AUTOCONFIG = array(
    "dbtype" => "pgsql",
    "dbname" => "${POSTGRES_DB}",
    "dbuser" => "${POSTGRES_USER}",
    "dbpass" => "${POSTGRES_PASSWORD}",
    "dbhost" => "${POSTGRES_HOST}",
    "dbtableprefix" => "oc_",
    "directory" => "/var/www/html/data",
);
EOF

# Set proper ownership
chown www-data:www-data /var/www/html/config/autoconfig.php
chmod 640 /var/www/html/config/autoconfig.php

echo "✅ Database pre-configured - setup wizard will only ask for admin account"

# Forward to original NextCloud entrypoint
echo "🌟 Starting NextCloud with original entrypoint..."
exec /entrypoint.sh apache2-foreground
