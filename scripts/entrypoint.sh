#!/bin/bash
set -e

echo "🚀 Starting NextCloud Railway deployment..."

# Function to wait for database
wait_for_db() {
    if [ -n "$DATABASE_URL" ]; then
        echo "⏳ Waiting for database to be ready..."
        # Parse DATABASE_URL (format: mysql://user:pass@host:port/dbname)
        DB_HOST=$(echo $DATABASE_URL | sed -n 's|mysql://[^:]*:[^@]*@\([^:]*\):.*|\1|p')
        DB_PORT=$(echo $DATABASE_URL | sed -n 's|mysql://[^:]*:[^@]*@[^:]*:\([0-9]*\)/.*|\1|p')
        DB_USER=$(echo $DATABASE_URL | sed -n 's|mysql://\([^:]*\):.*|\1|p')
        DB_PASS=$(echo $DATABASE_URL | sed -n 's|mysql://[^:]*:\([^@]*\)@.*|\1|p')
        
        while ! mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" --silent 2>/dev/null; do
            sleep 2
        done
        echo "✅ Database is ready!"
    else
        echo "⚠️ No DATABASE_URL found - using environment variables"
    fi
}

# Function to wait for Redis
wait_for_redis() {
    if [ -n "$REDIS_URL" ]; then
        echo "⏳ Waiting for Redis to be ready..."
        # Parse REDIS_URL (format: redis://host:port or redis://host:port/db)
        REDIS_HOST=$(echo $REDIS_URL | sed -n 's|redis://\([^:]*\):.*|\1|p')
        REDIS_PORT=$(echo $REDIS_URL | sed -n 's|redis://[^:]*:\([0-9]*\).*|\1|p')
        
        while ! redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping > /dev/null 2>&1; do
            sleep 2
        done
        echo "✅ Redis is ready!"
    else
        echo "⚠️ No REDIS_URL found - using default Redis settings"
    fi
}

# Parse Railway URLs and set individual components
parse_railway_urls() {
    # Parse DATABASE_URL if it exists (Railway auto-provides this)
    if [ -n "$DATABASE_URL" ]; then
        export DB_HOST=$(echo $DATABASE_URL | sed -n 's|mysql://[^:]*:[^@]*@\([^:]*\):.*|\1|p')
        export DB_PORT=$(echo $DATABASE_URL | sed -n 's|mysql://[^:]*:[^@]*@[^:]*:\([0-9]*\)/.*|\1|p')
        export DB_USER=$(echo $DATABASE_URL | sed -n 's|mysql://\([^:]*\):.*|\1|p')
        export DB_PASS=$(echo $DATABASE_URL | sed -n 's|mysql://[^:]*:\([^@]*\)@.*|\1|p')
        export DB_NAME=$(echo $DATABASE_URL | sed -n 's|.*/\([^?]*\).*|\1|p')
        echo "📊 Parsed database connection from DATABASE_URL"
    else
        # Fallback to individual env vars if DATABASE_URL not set
        export DB_HOST=${MYSQL_HOST:-localhost}
        export DB_PORT=${MYSQL_PORT:-3306}
        export DB_USER=${MYSQL_USER:-nextcloud}
        export DB_PASS=${MYSQL_PASSWORD:-nextcloud}
        export DB_NAME=${MYSQL_DATABASE:-nextcloud}
        echo "📊 Using individual database environment variables"
    fi
    
    # Parse REDIS_URL if it exists (Railway auto-provides this)
    if [ -n "$REDIS_URL" ]; then
        export REDIS_HOST=$(echo $REDIS_URL | sed -n 's|redis://\([^:]*\):.*|\1|p')
        export REDIS_PORT=$(echo $REDIS_URL | sed -n 's|redis://[^:]*:\([0-9]*\).*|\1|p')
        echo "🔴 Parsed Redis connection from REDIS_URL"
    else
        # Fallback values
        export REDIS_HOST=${REDIS_HOST:-localhost}
        export REDIS_PORT=${REDIS_PORT:-6379}
        echo "🔴 Using fallback Redis settings"
    fi
    
    # Set NextCloud domain from Railway
    export NC_DOMAIN=${RAILWAY_PUBLIC_DOMAIN:-localhost}
    export NC_PROTOCOL="https"
    export NC_URL="https://${NC_DOMAIN}"
    
    echo "🌐 NextCloud will be available at: $NC_URL"
}

# Create NextCloud configuration
create_nextcloud_config() {
    echo "🔧 Creating NextCloud configuration..."
    
    # Ensure config directory exists
    mkdir -p /var/www/html/config
    
    # Create the config file with Railway-compatible settings
    cat > /var/www/html/config/config.php << EOF
<?php
\$CONFIG = array(
  // Database configuration (from Railway DATABASE_URL)
  'dbtype' => 'mysql',
  'dbname' => '${DB_NAME}',
  'dbhost' => '${DB_HOST}',
  'dbport' => '${DB_PORT}',
  'dbtableprefix' => 'oc_',
  'mysql.utf8mb4' => true,
  'dbuser' => '${DB_USER}',
  'dbpassword' => '${DB_PASS}',

  // Redis configuration (from Railway REDIS_URL)
  'memcache.local' => '\\\\OC\\\\Memcache\\\\APCu',
  'memcache.distributed' => '\\\\OC\\\\Memcache\\\\Redis',
  'memcache.locking' => '\\\\OC\\\\Memcache\\\\Redis',
  'redis' => array(
    'host' => '${REDIS_HOST}',
    'port' => ${REDIS_PORT},
    'timeout' => 0.0,
  ),

  // Railway proxy and domain settings
  'trusted_domains' => array(
    0 => '${NC_DOMAIN}',
    1 => 'localhost',
  ),
  'overwriteprotocol' => '${NC_PROTOCOL}',
  'overwritehost' => '${NC_DOMAIN}',
  'overwritecliurl' => '${NC_URL}',
  
  // Railway uses proxies, so trust Railway's network
  'trusted_proxies' => array('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'),
  'forwarded_for_headers' => array('HTTP_X_FORWARDED_FOR'),

  // Performance settings (fixes performance warnings)
  'enable_previews' => true,
  'preview_max_x' => 1024,
  'preview_max_y' => 768,
  'filesystem_check_changes' => 0,
  'part_file_in_storage' => false,

  // Security settings (fixes security warnings)
  'default_phone_region' => 'US',
  'auth.bruteforce.protection.enabled' => true,
  'maintenance_window_start' => 2,
  'upgrade.disable-web' => true,

  // Logging
  'log_type' => 'file',
  'logfile' => '/var/www/html/data/nextcloud.log',
  'loglevel' => 2,
  'logdateformat' => 'F d, Y H:i:s',

  // Session settings
  'session_lifetime' => 60 * 60 * 24,
  'session_keepalive' => true,

  // App settings
  'default_locale' => 'en',
  'default_language' => 'en',
  'defaultapp' => 'files',

  // Data directory
  'datadirectory' => '/var/www/html/data',

  // App directories
  'apps_paths' => array(
    array(
      'path' => '/var/www/html/apps',
      'url' => '/apps',
      'writable' => false,
    ),
    array(
      'path' => '/var/www/html/custom_apps',
      'url' => '/custom_apps',
      'writable' => true,
    ),
  ),

  // Skip some checks that don't work well in Railway/containers
  'check_for_working_wellknown_setup' => false,
  'check_for_working_htaccess' => false,
  'updatechecker' => false,
  
  // Installation flag (will be set to true after setup)
  'installed' => false,
);
EOF

    chown www-data:www-data /var/www/html/config/config.php
    chmod 640 /var/www/html/config/config.php
    echo "✅ NextCloud configuration created!"
}

# Set up cron for NextCloud background jobs
setup_cron() {
    echo "⏰ Setting up NextCloud cron jobs..."
    
    # Create cron job for NextCloud (every 5 minutes)
    echo "*/5 * * * * php -f /var/www/html/cron.php" | crontab -u www-data -
    
    echo "✅ Cron jobs configured!"
}

# Post-installation optimizations (run after NextCloud setup completes)
optimize_after_install() {
    echo "🔧 Starting post-installation optimizations..."
    
    # Wait for NextCloud to be fully installed
    local max_attempts=60  # 10 minutes max
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if [ -f /var/www/html/config/config.php ] && grep -q "installed.*true" /var/www/html/config/config.php 2>/dev/null; then
            echo "✅ NextCloud installation detected!"
            break
        fi
        echo "⏳ Waiting for NextCloud installation... (attempt $((attempt + 1))/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        echo "⚠️ Timeout waiting for NextCloud installation"
        return 1
    fi
    
    # Install and enable Talk app
    echo "📞 Installing NextCloud Talk app..."
    sudo -u www-data php /var/www/html/occ app:install spreed --no-interaction || echo "Talk app installation failed or already installed"
    sudo -u www-data php /var/www/html/occ app:enable spreed --no-interaction || echo "Talk app enable failed"
    
    # Add missing database indices (fixes performance warnings)
    echo "📊 Adding missing database indices..."
    sudo -u www-data php /var/www/html/occ db:add-missing-indices --no-interaction || echo "Adding indices failed"
    
    # Add missing primary keys (fixes security warnings)
    echo "🔑 Adding missing primary keys..."
    sudo -u www-data php /var/www/html/occ db:add-missing-primary-keys --no-interaction || echo "Adding primary keys failed"
    
    # Convert to big int (fixes compatibility warnings)
    echo "🔢 Converting file cache to big int..."
    sudo -u www-data php /var/www/html/occ db:convert-filecache-bigint --no-interaction || echo "Big int conversion failed"
    
    # Set background job mode to cron (fixes cron warning)
    echo "⚙️ Setting background job mode to cron..."
    sudo -u www-data php /var/www/html/occ background:cron --no-interaction || echo "Setting background job failed"
    
    # Configure Talk HPB if secrets are provided
    if [ -n "$SIGNALING_SECRET" ] && [ -n "$NC_DOMAIN" ]; then
        echo "📞 Configuring Talk High-Performance Backend..."
        # Note: This assumes HPB is deployed separately with a subdomain
        local hpb_url="https://hpb-${NC_DOMAIN}"
        if [ -n "$HPB_URL" ]; then
            hpb_url="$HPB_URL"
        fi
        
        sudo -u www-data php /var/www/html/occ config:app:set spreed signaling_servers --value="[{\"server\":\"${hpb_url}\",\"verify\":true}]" --no-interaction || echo "HPB server config failed"
        sudo -u www-data php /var/www/html/occ config:app:set spreed signaling_secret --value="$SIGNALING_SECRET" --no-interaction || echo "HPB secret config failed"
        echo "✅ Talk HPB configured for: $hpb_url"
    else
        echo "⚠️ SIGNALING_SECRET not set - Talk HPB not configured"
    fi
    
    echo "✅ Post-installation optimizations complete!"
}

# Main execution flow
echo "🚀 Starting NextCloud Railway setup..."

# Parse Railway environment variables
parse_railway_urls

# Wait for required services
wait_for_db
wait_for_redis

# Create NextCloud configuration
create_nextcloud_config

# Set up cron jobs
setup_cron

# Start background optimization (runs after NextCloud setup)
(sleep 60 && optimize_after_install) &

# Start supervisord to manage all processes
echo "🌟 Starting NextCloud with supervisor..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
