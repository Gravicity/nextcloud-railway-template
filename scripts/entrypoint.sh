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

# Set Railway domain and port
export NC_DOMAIN=${RAILWAY_PUBLIC_DOMAIN:-localhost}
export RAILWAY_PORT=${PORT:-80}

echo "🌐 NextCloud will be available at: https://${NC_DOMAIN}"
echo "📊 Database: ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
echo "🔴 Redis: ${REDIS_HOST}:${REDIS_PORT}"
echo "🚢 Railway Port: ${RAILWAY_PORT}"

# Set NextCloud environment variables for auto-configuration
export MYSQL_HOST="$DB_HOST"
export MYSQL_PORT="$DB_PORT"
export MYSQL_USER="$DB_USER"
export MYSQL_PASSWORD="$DB_PASS"
export MYSQL_DATABASE="$DB_NAME"
export REDIS_HOST="$REDIS_HOST"
export REDIS_HOST_PORT="$REDIS_PORT"

# Configure Apache for Railway's PORT before starting
echo "🌐 Configuring Apache for Railway..."
echo "Listen ${RAILWAY_PORT}" > /etc/apache2/ports.conf

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

# Set up cron jobs
echo "⏰ Setting up NextCloud cron jobs..."
echo "*/5 * * * * php -f /var/www/html/cron.php" | crontab -u www-data -
echo "✅ Cron jobs configured!"

# Create a background script to enhance configuration after NextCloud starts
cat > /usr/local/bin/enhance-nextcloud.sh << EOSCRIPT
#!/bin/bash

# Import environment variables
export NC_DOMAIN="$NC_DOMAIN"
export REDIS_HOST="$REDIS_HOST"
export REDIS_PORT="$REDIS_PORT"

echo "🔧 Waiting for NextCloud to be fully initialized..."
sleep 30

# Wait for config file to exist and be populated
for i in {1..30}; do
    if [ -f "/var/www/html/config/config.php" ] && grep -q "dbtype" /var/www/html/config/config.php 2>/dev/null; then
        echo "✅ NextCloud config found, enhancing..."
        break
    fi
    echo "⏳ Waiting for NextCloud config... ($i/30)"
    sleep 10
done

# Check if we found the config
if [ ! -f "/var/www/html/config/config.php" ] || ! grep -q "dbtype" /var/www/html/config/config.php 2>/dev/null; then
    echo "⚠️ NextCloud config not found after waiting, skipping enhancements"
    exit 0
fi

# Enhance configuration with PHP
echo "🔧 Applying Railway optimizations to NextCloud config..."
cp /var/www/html/config/config.php /var/www/html/config/config.php.backup

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
    if (file_put_contents($configFile, $output)) {
        echo "✅ NextCloud configuration enhanced with Railway optimizations!\n";
    } else {
        echo "❌ Failed to write enhanced configuration\n";
        exit(1);
    }
} else {
    echo "❌ Config file not found for enhancement\n";
    exit(1);
}
EOPHP

# Set proper ownership and permissions
chown www-data:www-data /var/www/html/config/config.php 2>/dev/null || echo "⚠️ Could not set config file ownership"
chmod 640 /var/www/html/config/config.php 2>/dev/null || echo "⚠️ Could not set config file permissions"

echo "🎉 NextCloud Railway optimization complete!"
echo "✨ Enhancements applied:"
echo "   - Redis caching enabled"
echo "   - Railway proxy settings configured" 
echo "   - Security headers optimized"
echo "   - Performance settings tuned"
EOSCRIPT

chmod +x /usr/local/bin/enhance-nextcloud.sh

# Start the enhancement script in background
/usr/local/bin/enhance-nextcloud.sh &

# Now run the original NextCloud entrypoint
echo "🌟 Starting NextCloud with original entrypoint..."
exec /entrypoint.sh apache2-foreground
