#!/bin/bash
# NextCloud Security & Setup Warnings Fix Script
# Run this after NextCloud is fully installed and configured

set -e

echo "🔧 Fixing NextCloud Security & Setup Warnings..."

# Function to run occ commands as www-data user
run_occ() {
    if command -v sudo >/dev/null 2>&1; then
        sudo -u www-data php /var/www/html/occ "$@"
    else
        # In Railway, we might be running as root already
        runuser -u www-data -- php /var/www/html/occ "$@" 2>/dev/null || php /var/www/html/occ "$@"
    fi
}

# Wait for NextCloud to be ready
echo "⏳ Waiting for NextCloud to be ready..."
until run_occ status | grep -q "installed: true"; do
    echo "⏳ NextCloud not ready yet, waiting..."
    sleep 10
done

echo "✅ NextCloud is ready, proceeding with fixes..."

# Fix database issues
echo "🗄️ Adding missing database columns..."
run_occ db:add-missing-columns

echo "📊 Adding missing database indices..."
run_occ db:add-missing-indices

echo "🔑 Adding missing primary keys..."
run_occ db:add-missing-primary-keys

# Fix mimetype migrations
echo "📁 Running mimetype migrations..."
run_occ maintenance:repair --include-expensive

# Update system configurations
echo "⚙️ Updating system configurations..."
run_occ config:system:set maintenance_window_start --value=2 --type=integer
run_occ config:system:set default_phone_region --value="US"

# Enable recommended caching if Redis is available
if [ -n "$REDIS_HOST" ]; then
    echo "🔴 Configuring Redis caching..."
    run_occ config:system:set memcache.local --value="\\OC\\Memcache\\APCu"
    run_occ config:system:set memcache.distributed --value="\\OC\\Memcache\\Redis"
    run_occ config:system:set memcache.locking --value="\\OC\\Memcache\\Redis"
fi

# Disable update checker for containerized deployments
echo "📦 Configuring for containerized deployment..."
run_occ config:system:set updatechecker --value=false --type=boolean

# Run final maintenance
echo "🧹 Running final maintenance..."
run_occ maintenance:mode --off

echo "✅ NextCloud Security & Setup Warnings fixed successfully!"
echo "ℹ️  You may need to refresh your NextCloud admin page to see the changes."
