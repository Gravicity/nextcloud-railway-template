#!/bin/bash
# NextCloud Security & Setup Warnings Fix Script
# Run this after NextCloud is fully installed and configured

set -e

echo "🔧 Fixing NextCloud Security & Setup Warnings..."

# Wait for NextCloud to be ready
echo "⏳ Waiting for NextCloud to be ready..."
until sudo -u www-data php /var/www/html/occ status | grep -q "installed: true"; do
    echo "⏳ NextCloud not ready yet, waiting..."
    sleep 10
done

echo "✅ NextCloud is ready, proceeding with fixes..."

# Fix database issues
echo "🗄️ Adding missing database columns..."
sudo -u www-data php /var/www/html/occ db:add-missing-columns

echo "📊 Adding missing database indices..."
sudo -u www-data php /var/www/html/occ db:add-missing-indices

echo "🔑 Adding missing primary keys..."
sudo -u www-data php /var/www/html/occ db:add-missing-primary-keys

# Fix mimetype migrations
echo "📁 Running mimetype migrations..."
sudo -u www-data php /var/www/html/occ maintenance:repair --include-expensive

# Update system configurations
echo "⚙️ Updating system configurations..."
sudo -u www-data php /var/www/html/occ config:system:set maintenance_window_start --value=2 --type=integer
sudo -u www-data php /var/www/html/occ config:system:set default_phone_region --value="US"

# Enable recommended caching if Redis is available
if [ -n "$REDIS_HOST" ]; then
    echo "🔴 Configuring Redis caching..."
    sudo -u www-data php /var/www/html/occ config:system:set memcache.local --value="\\OC\\Memcache\\APCu"
    sudo -u www-data php /var/www/html/occ config:system:set memcache.distributed --value="\\OC\\Memcache\\Redis"
    sudo -u www-data php /var/www/html/occ config:system:set memcache.locking --value="\\OC\\Memcache\\Redis"
fi

# Disable update checker for containerized deployments
echo "📦 Configuring for containerized deployment..."
sudo -u www-data php /var/www/html/occ config:system:set updatechecker --value=false --type=boolean

# Run final maintenance
echo "🧹 Running final maintenance..."
sudo -u www-data php /var/www/html/occ maintenance:mode --off

echo "✅ NextCloud Security & Setup Warnings fixed successfully!"
echo "ℹ️  You may need to refresh your NextCloud admin page to see the changes."
