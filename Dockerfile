FROM nextcloud:latest

# Install additional packages and PHP extensions
RUN apt-get update && apt-get install -y \
    smbclient \
    libsmbclient-dev \
    cron \
    supervisor \
    redis-tools \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Install smbclient PHP extension
RUN pecl install smbclient \
    && docker-php-ext-enable smbclient

# Copy PHP configuration
COPY config/php.ini /usr/local/etc/php/conf.d/nextcloud.ini

# Copy Apache configurations
COPY config/security.conf /etc/apache2/conf-available/security.conf
COPY config/apache-security.conf /etc/apache2/conf-available/apache-security.conf

# Enable Apache configurations and modules
RUN a2enconf security apache-security && \
    a2enmod rewrite headers env dir mime && \
    # Enable PHP module (version may vary)
    (a2enmod php8.3 || a2enmod php || echo "PHP module detection will be handled in entrypoint")

# Copy supervisor configuration
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy custom entrypoint
COPY scripts/entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

# Create necessary directories and set permissions
RUN mkdir -p /var/log/supervisor && \
    # Ensure NextCloud files are present and accessible
    ls -la /var/www/html/ && \
    # Set proper ownership and permissions
    chown -R www-data:www-data /var/www/html && \
    find /var/www/html -type f -exec chmod 644 {} \; && \
    find /var/www/html -type d -exec chmod 755 {} \; && \
    chmod +x /usr/local/bin/custom-entrypoint.sh

# Expose HTTP port (Railway uses PORT env variable)
EXPOSE 8080

# Use custom entrypoint (handles everything including starting supervisord)
ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
