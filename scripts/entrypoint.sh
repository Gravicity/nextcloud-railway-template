#!/bin/bash
set -e

echo "🚀 Starting NextCloud Railway deployment..."

# Parse Railway environment variables
if [ -n "$DATABASE_URL" ]; then
    echo "📊 Using DATABASE_URL"
    export DB_HOST=$(echo $DATABASE_URL | sed -n 's|mysql://[^:]*:[^@]*@\([^:]*\):.*|\1|p')
    export DB_PORT=$(echo $DATABASE_URL | sed -n 's|mysql://[^:]*:[^@]*@[^:]*:\([0-9]*\)/.*|\1|p')
    export DB_USER=$(echo $DATABASE_URL | sed -n 's|mysql://\([^:]*\):.*|\1|p')
    export DB_PASS=$(echo $DATABASE_URL | sed -n 's|mysql://[^:]*:\([^@]*\)@.*|\1|p')
    export DB_NAME=$(echo $DATABASE_URL | sed -n 's|.*/\([^?]*\).*|\1|p')
elif [ -n "$MYSQL_URL" ]; then
    echo "📊 Using MYSQL_URL"
    export DB_HOST=$(echo $MYSQL_URL | sed -n 's|mysql://[^:]*:[^@]*@\([^:]*\):.*|\1|p')
    export DB_PORT=$(echo $MYSQL_URL | sed -n 's|mysql://[^:]*:[^@]*@[^:]*:\([0-9]*\)/.*|\1|p')
    export DB_USER=$(echo $MYSQL_URL | sed -n 's|mysql://\([^:]*\):.*|\1|p')
    export DB_PASS=$(echo $MYSQL_URL | sed -n 's|mysql://[^:]*:\([^@]*\)@.*|\1|p')
    export DB_NAME=$(echo $MYSQL_URL | sed -n 's|.*/\([^?]*\).*|\1|p')
else
    export DB_HOST=${MYSQLHOST:-localhost}
    export DB_PORT=${MYSQLPORT:-3306}
    export DB_USER=${MYSQLUSER:-root}
    export DB_PASS=${MYSQLPASSWORD:-}
    export DB_NAME=${MYSQLDATABASE:-railway}
    echo "📊 Using individual MySQL environment variables"
fi

if [ -n "$REDIS_URL" ]; then
    echo "🔴 Using REDIS_URL"
    export REDIS_HOST=$(echo $REDIS_URL | sed -n 's|redis://[^@]*@\?\([^:]*\):.*|\1|p')
    export REDIS_PORT=$(echo $REDIS_URL | sed -n 's|redis://[^@]*@\?[^:]*:\([0-9]*\).*|\1|p')
else
    export REDIS_HOST=${REDISHOST:-localhost}
    export REDIS_PORT=${REDISPORT:-6379}
    echo "🔴 Using individual Redis environment variables"
fi

# Set Railway domain
export NC_DOMAIN=${RAILWAY_PUBLIC_DOMAIN:-localhost}
export RAILWAY_PORT=${PORT:-80}

echo "🌐 NextCloud will be available at: https://${NC_DOMAIN}"
echo "📊 Database: ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
echo "🔴 Redis: ${REDIS_HOST}:${REDIS_PORT}"
echo "🚢 Railway Port: ${RAILWAY_PORT}"

# Configure Apache for Railway's PORT
echo "🌐 Configuring Apache for Railway..."
echo "Listen ${RAILWAY_PORT}" > /etc/apache2/ports.conf

# Create proper Apache virtual host configuration
cat > /etc/apache2/sites-available/000-default.conf << EOF
<VirtualHost *:${RAILWAY_PORT}>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    
    DirectoryIndex index.php index.html
    
    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

echo "✅ Apache configured for port: ${RAILWAY_PORT}"

# Verify NextCloud files
if [ -f "/var/www/html/index.php" ]; then
    echo "✅ NextCloud files found"
else
    echo "❌ NextCloud files missing!"
    ls -la /var/www/html/
fi

# Wait for database if needed
if [ -n "$DB_HOST" ] && [ "$DB_HOST" != "localhost" ]; then
    echo "⏳ Waiting for database..."
    for i in {1..30}; do
        if mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" --silent 2>/dev/null; then
            echo "✅ Database ready!"
            break
        fi
        echo "⏳ Database not ready, attempt $i/30..."
        sleep 2
    done
fi

# Wait for Redis if needed
if [ -n "$REDIS_HOST" ] && [ "$REDIS_HOST" != "localhost" ]; then
    echo "⏳ Waiting for Redis..."
    for i in {1..30}; do
        if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping > /dev/null 2>&1; then
            echo "✅ Redis ready!"
            break
        fi
        echo "⏳ Redis not ready, attempt $i/30..."
        sleep 2
    done
fi

# Create initial NextCloud configuration (only if no config exists)
create_initial_config() {
    if [ ! -f "/var/www/html/config/config.php" ]; then
        echo "🔧 Creating initial NextCloud configuration..."
        mkdir -p /var/www/html/config

        cat > /var/www/html/config/config.php << EOF
<?php
\$CONFIG = array(
  'dbtype' => 'mysql',
  'dbname' => '${DB_NAME}',
  'dbhost' => '${DB_HOST}',
  'dbport' => '${DB_PORT}',
  'dbtableprefix' => 'oc_',
  'mysql.utf8mb4' => true,
  'dbuser' => '${DB_USER}',
  'dbpassword' => '${DB_PASS}',

  'trusted_domains' => array(
    0 => '${NC_DOMAIN}',
    1 => 'localhost',
  ),
  'overwriteprotocol' => 'https',
  'overwritehost' => '${NC_DOMAIN}',
  'overwritecliurl' => 'https://${NC_DOMAIN}',
  
  'datadirectory' => '/var/www/html/data',
  'installed' => false,
);
EOF

        chown www-data:www-data /var/www/html/config/config.php
        chmod 640 /var/www/html/config/config.php
        echo "✅ Initial NextCloud configuration created!"
    else
        echo "ℹ️ NextCloud config already exists, skipping initial creation"
    fi
}

# Enhance existing NextCloud configuration with our optimizations
enhance_nextcloud_config() {
    if [ -f "/var/www/html/config/config.php" ]; then
        echo "🔧 Enhancing NextCloud configuration with optimizations..."
        
        # Backup original config
        cp /var/www/html/config/config.php /var/www/html/config/config.php.backup
        
        # Use PHP to merge our enhancements into existing config
        php << 'EOPHP'
<?php
$configFile = '/var/www/html/config/config.php';
if (file_exists($configFile)) {
    include $configFile;
    
    // Merge our optimizations
    $CONFIG = array_merge($CONFIG, array(
        // Redis configuration
        'memcache.local' => '\\OC\\Memcache\\APCu',
        'memcache.distributed' => '\\OC\\Memcache\\Redis',
        'memcache.locking' => '\\OC\\Memcache\\Redis',
        'redis' => array(
            'host' => getenv('REDIS_HOST') ?: 'localhost',
            'port' => intval(getenv('REDIS_PORT') ?: 6379),
            'timeout' => 0.0,
        ),

        // Railway proxy settings
        'trusted_proxies' => array('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'),
        'forwarded_for_headers' => array('HTTP_X_FORWARDED_FOR'),
        'overwriteprotocol' => 'https',
        'overwritehost' => getenv('NC_DOMAIN') ?: 'localhost',
        'overwritecliurl' => 'https://' . (getenv('NC_DOMAIN') ?: 'localhost'),

        // Performance optimizations
        'enable_previews' => true,
        'preview_max_x' => 1024,
        'preview_max_y' => 768,
        'filesystem_check_changes' => 0,

        // Security optimizations
        'default_phone_region' => 'US',
        'auth.bruteforce.protection.enabled' => true,
        'maintenance_window_start' => 2,
        'upgrade.disable-web' => true,

        // Skip container-incompatible checks
        'check_for_working_wellknown_setup' => false,
        'check_for_working_htaccess' => false,
        'updatechecker' => false,
    ));
    
    // Write enhanced config
    $output = "<?php\n\$CONFIG = " . var_export($CONFIG, true) . ";\n";
    file_put_contents($configFile, $output);
    echo "✅ NextCloud configuration enhanced with optimizations!\n";
} else {
    echo "❌ Config file not found for enhancement\n";
}
EOPHP

        chown www-data:www-data /var/www/html/config/config.php
        chmod 640 /var/www/html/config/config.php
    else
        echo "⚠️ No existing config found to enhance"
    fi
}

# Set up cron jobs
echo "⏰ Setting up NextCloud cron jobs..."
echo "*/5 * * * * php -f /var/www/html/cron.php" | crontab -u www-data -
echo "✅ Cron jobs configured!"

# If NextCloud files are missing, run the original entrypoint first
if [ ! -f "/var/www/html/index.php" ]; then
    echo "🔄 NextCloud files missing - running original entrypoint to initialize..."
    
    # Set NextCloud auto-configuration environment variables
    export NEXTCLOUD_INIT_HTACCESS=true
    export MYSQL_HOST="$DB_HOST"
    export MYSQL_PORT="$DB_PORT"
    export MYSQL_USER="$DB_USER"
    export MYSQL_PASSWORD="$DB_PASS"
    export MYSQL_DATABASE="$DB_NAME"
    export REDIS_HOST="$REDIS_HOST"
    export REDIS_HOST_PORT="$REDIS_PORT"
    
    # Run original NextCloud entrypoint in background to populate files
    /entrypoint.sh apache2-foreground &
    ORIGINAL_PID=$!
    
    # Wait for NextCloud initialization to complete
    for i in {1..60}; do
        if [ -f "/var/www/html/config/config.php" ] && grep -q "installed.*true" /var/www/html/config/config.php 2>/dev/null; then
            echo "✅ NextCloud initialization complete!"
            # Kill the background process
            kill $ORIGINAL_PID 2>/dev/null || true
            sleep 2
            break
        elif [ -f "/var/www/html/index.php" ]; then
            echo "📁 NextCloud files available, waiting for config... ($i/60)"
        else
            echo "⏳ Waiting for NextCloud initialization... ($i/60)"
        fi
        sleep 2
    done
    
    # Now enhance the configuration with our optimizations
    echo "🔧 Enhancing NextCloud configuration..."
    enhance_nextcloud_config
else
    echo "✅ NextCloud files already present"
    # Create initial config for first-time setup
    create_initial_config
fi

# Final verification
if [ -f "/var/www/html/index.php" ]; then
    echo "✅ NextCloud ready for startup"
else
    echo "❌ NextCloud files still missing after initialization!"
    exit 1
fi

# Start supervisor
echo "🌟 Starting NextCloud with supervisor..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
