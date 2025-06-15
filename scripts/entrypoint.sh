#!/bin/bash
set -e

echo "🚀 Starting NextCloud Railway deployment..."

# Parse Railway environment variables for PostgreSQL database
if [ -n "$DATABASE_URL" ]; then
    echo "📊 Using DATABASE_URL (PostgreSQL)"
    export POSTGRES_HOST=$(echo $DATABASE_URL | sed -n 's|postgresql://[^:]*:[^@]*@\([^:]*\):.*|\1|p')
    export POSTGRES_USER=$(echo $DATABASE_URL | sed -n 's|postgresql://\([^:]*\):.*|\1|p')
    export POSTGRES_PASSWORD=$(echo $DATABASE_URL | sed -n 's|postgresql://[^:]*:\([^@]*\)@.*|\1|p')
    export POSTGRES_DB=$(echo $DATABASE_URL | sed -n 's|.*/\([^?]*\).*|\1|p')
    echo "📊 Database: ${POSTGRES_USER}@${POSTGRES_HOST}/${POSTGRES_DB}"
fi

# Parse Railway environment variables for Redis
if [ -n "$REDIS_URL" ]; then
    echo "🔴 Using REDIS_URL"
    export REDIS_HOST=$(echo $REDIS_URL | sed -n 's|redis://[^:]*:[^@]*@\([^:]*\):.*|\1|p')
    export REDIS_HOST_PORT=$(echo $REDIS_URL | sed -n 's|redis://[^:]*:[^@]*@[^:]*:\([0-9]*\).*|\1|p')
    export REDIS_HOST_PASSWORD=$(echo $REDIS_URL | sed -n 's|redis://[^:]*:\([^@]*\)@.*|\1|p')
    echo "🔴 Redis: ${REDIS_HOST}:${REDIS_HOST_PORT}"
fi

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
