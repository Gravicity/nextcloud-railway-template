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

# Create NextCloud configuration
echo "🔧 Creating NextCloud configuration..."
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

  'memcache.local' => '\\\\OC\\\\Memcache\\\\APCu',
  'memcache.distributed' => '\\\\OC\\\\Memcache\\\\Redis',
  'memcache.locking' => '\\\\OC\\\\Memcache\\\\Redis',
  'redis' => array(
    'host' => '${REDIS_HOST}',
    'port' => ${REDIS_PORT},
    'timeout' => 0.0,
  ),

  'trusted_domains' => array(
    0 => '${NC_DOMAIN}',
    1 => 'localhost',
  ),
  'overwriteprotocol' => 'https',
  'overwritehost' => '${NC_DOMAIN}',
  'overwritecliurl' => 'https://${NC_DOMAIN}',
  
  'trusted_proxies' => array('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'),
  'forwarded_for_headers' => array('HTTP_X_FORWARDED_FOR'),

  'enable_previews' => true,
  'preview_max_x' => 1024,
  'preview_max_y' => 768,
  'filesystem_check_changes' => 0,

  'default_phone_region' => 'US',
  'auth.bruteforce.protection.enabled' => true,
  'maintenance_window_start' => 2,
  'upgrade.disable-web' => true,

  'log_type' => 'file',
  'logfile' => '/var/www/html/data/nextcloud.log',
  'loglevel' => 2,

  'session_lifetime' => 60 * 60 * 24,
  'session_keepalive' => true,

  'default_locale' => 'en',
  'default_language' => 'en',
  'defaultapp' => 'files',

  'datadirectory' => '/var/www/html/data',

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

  'check_for_working_wellknown_setup' => false,
  'check_for_working_htaccess' => false,
  'update
