# Base stage for dependencies
FROM php:8.2-fpm as vendor

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git curl unzip libpq-dev libonig-dev libzip-dev zip \
    && docker-php-ext-install pdo pdo_mysql mbstring zip

WORKDIR /var/www

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy only composer files to leverage caching
COPY composer.json composer.lock ./

# Install PHP dependencies
RUN composer install --no-dev --optimize-autoloader

# Final stage
FROM php:8.2-fpm as app

# Install only necessary runtime extensions
RUN apt-get update && apt-get install -y libpq-dev libzip-dev \
    && docker-php-ext-install pdo pdo_mysql mbstring zip \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /var/www

# Copy vendor files from the vendor stage
COPY --from=vendor /var/www/vendor ./vendor

# Copy the rest of the application files
COPY . .

# Set permissions for storage and bootstrap/cache
RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache && \
    chmod -R 775 /var/www/storage /var/www/bootstrap/cache

# Generate application key and cache configuration
RUN php artisan key:generate --force && \
    php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache

# Expose port 9000 and start php-fpm server
EXPOSE 9000
CMD ["php-fpm"]
