#!/bin/bash
set -e

echo "🚀 Starting NextCloud Railway deployment..."

# Configure Apache for Railway's PORT
export PORT=${PORT:-80}
echo "Listen $PORT" > /etc/apache2/ports.conf
echo "✅ Apache configured for port: $PORT"

# Set Railway domain for trusted domains
if [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
    echo "🌐 Setting trusted domain: $RAILWAY_PUBLIC_DOMAIN"
    export NEXTCLOUD_TRUSTED_DOMAINS="$RAILWAY_PUBLIC_DOMAIN localhost"
fi

# Forward to original NextCloud entrypoint
echo "🌟 Starting NextCloud with original entrypoint..."
exec /entrypoint.sh apache2-foreground
