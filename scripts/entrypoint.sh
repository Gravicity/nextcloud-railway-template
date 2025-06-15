#!/bin/bash
set -e

echo "🚀 Starting NextCloud Railway deployment..."

# Verify we have required environment variables
if [ -z "$POSTGRES_HOST" ] || [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_PASSWORD" ] || [ -z "$POSTGRES_DB" ]; then
    echo "❌ Missing required PostgreSQL environment variables!"
    echo "Required: POSTGRES_HOST, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB"
    exit 1
fi

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
