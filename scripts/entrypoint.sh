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

# Forward to original NextCloud entrypoint
echo "🌟 Starting NextCloud with original entrypoint..."
exec /entrypoint.sh apache2-foreground
