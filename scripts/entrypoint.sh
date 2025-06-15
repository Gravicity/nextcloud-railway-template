#!/bin/bash
set -e

echo "🚀 Starting NextCloud Railway deployment..."

# Debug: Print all environment variables starting with POSTGRES or REDIS
echo "🔍 Debug: Environment variables:"
env | grep -E "^(POSTGRES|REDIS|RAILWAY)" | sort

# Check for environment variables - we need at least some PostgreSQL config
if [ -z "$POSTGRES_HOST" ] && [ -z "$DATABASE_URL" ] && [ -z "$POSTGRES_USER" ]; then
    echo "❌ No PostgreSQL configuration found!"
    echo "Set either individual POSTGRES_* variables or DATABASE_URL"
    echo "Available environment variables:"
    env | grep -E "^(PG|POSTGRES|DATABASE)" | sort
    exit 1
fi

# If DATABASE_URL is provided, parse it
if [ -n "$DATABASE_URL" ] && [ -z "$POSTGRES_HOST" ]; then
    echo "📊 Parsing DATABASE_URL..."
    export POSTGRES_HOST=$(echo $DATABASE_URL | sed -n 's|postgresql://[^:]*:[^@]*@\([^:]*\):.*|\1|p')
    export POSTGRES_PORT=$(echo $DATABASE_URL | sed -n 's|postgresql://[^:]*:[^@]*@[^:]*:\([0-9]*\)/.*|\1|p')
    export POSTGRES_USER=$(echo $DATABASE_URL | sed -n 's|postgresql://\([^:]*\):.*|\1|p')
    export POSTGRES_PASSWORD=$(echo $DATABASE_URL | sed -n 's|postgresql://[^:]*:\([^@]*\)@.*|\1|p')
    export POSTGRES_DB=$(echo $DATABASE_URL | sed -n 's|.*/\([^?]*\).*|\1|p')
fi

# Set defaults if still missing (but keep existing values)
export POSTGRES_HOST=${POSTGRES_HOST:-$PGHOST}
export POSTGRES_HOST=${POSTGRES_HOST:-localhost}
export POSTGRES_PORT=${POSTGRES_PORT:-$PGPORT}
export POSTGRES_PORT=${POSTGRES_PORT:-5432}
export POSTGRES_USER=${POSTGRES_USER:-$PGUSER}
export POSTGRES_USER=${POSTGRES_USER:-postgres}
export POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$PGPASSWORD}
export POSTGRES_DB=${POSTGRES_DB:-$PGDATABASE}
export POSTGRES_DB=${POSTGRES_DB:-nextcloud}

# Configure Apache for Railway's PORT
export PORT=${PORT:-80}
echo "Listen $PORT" > /etc/apache2/ports.conf
echo "✅ Apache configured for port: $PORT"

# Display configuration info  
echo "📊 Database: ${POSTGRES_USER}@${POSTGRES_HOST}:${POSTGRES_PORT:-5432}/${POSTGRES_DB}"
echo "🔴 Redis: ${REDIS_HOST}:${REDIS_HOST_PORT}"
echo "🌐 Trusted domains: ${NEXTCLOUD_TRUSTED_DOMAINS}"

# Wait for NextCloud entrypoint to initialize first
echo "🌟 Starting NextCloud with original entrypoint..."

# Create a hook script that runs after NextCloud initialization
mkdir -p /docker-entrypoint-hooks.d/before-starting

cat > /docker-entrypoint-hooks.d/before-starting/01-setup-autoconfig.sh << 'EOF'
#!/bin/bash
echo "🔧 Setting up database auto-configuration..."

# Only create autoconfig if NextCloud isn't already installed
if [ ! -f "/var/www/html/config/config.php" ]; then
    mkdir -p /var/www/html/config
    
    # Create autoconfig.php for automatic database setup
    cat > /var/www/html/config/autoconfig.php << AUTOEOF
<?php
\$AUTOCONFIG = array(
    "dbtype" => "pgsql",
    "dbname" => "${POSTGRES_DB}",
    "dbuser" => "${POSTGRES_USER}",
    "dbpass" => "${POSTGRES_PASSWORD}",
    "dbhost" => "${POSTGRES_HOST}:${POSTGRES_PORT:-5432}",
    "dbtableprefix" => "oc_",
    "directory" => "/var/www/html/data",
    "trusted_domains" => array(
        0 => "localhost",
        1 => "${RAILWAY_PUBLIC_DOMAIN}",
    ),
);
AUTOEOF

    # Set proper ownership and permissions
    chown www-data:www-data /var/www/html/config/autoconfig.php
    chmod 640 /var/www/html/config/autoconfig.php
    
    echo "✅ Auto-configuration created successfully"
else
    echo "✅ NextCloud already configured"
fi
EOF

chmod +x /docker-entrypoint-hooks.d/before-starting/01-setup-autoconfig.sh

# Forward to original NextCloud entrypoint
exec /entrypoint.sh apache2-foreground
