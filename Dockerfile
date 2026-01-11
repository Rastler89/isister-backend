FROM php:8.3-cli AS base

# 1. Paquetes del sistema con ca-certificates
RUN apt-get update && apt-get install -y \
    git unzip curl libpng-dev libonig-dev libxml2-dev \
    libzip-dev libpq-dev libcurl4-openssl-dev libssl-dev \
    zlib1g-dev libicu-dev g++ libevent-dev procps ca-certificates openssl \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql mbstring zip exif pcntl bcmath sockets intl

# 2. Instalación de Swoole (Simplificada y robusta)
RUN pecl install swoole-5.1.0 && docker-php-ext-enable swoole

# 3. Node y Composer
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && apt-get install -y nodejs
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

# 4. COPIAR TODO EL PROYECTO PRIMERO 
# (Esto evita que composer install falle por falta de archivos referenciados en el json)
COPY . .

# 5. Crear estructura de carpetas necesaria
RUN mkdir -p bootstrap/cache storage/app storage/framework/cache/data \
    storage/framework/sessions storage/framework/views storage/logs

# 6. Install Composer con ignorar requisitos de plataforma por si acaso
RUN composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist --ignore-platform-reqs

# 7. Frontend (Vite)
RUN npm install && npm run build

# 8. Permisos
RUN chown -R www-data:www-data /var/www \
    && chmod -R 775 /var/www/storage /var/www/bootstrap/cache

EXPOSE 9000

# 9. CMD optimizado para Dokploy
# Usamos "sh -c" para que las variables de entorno se expandan correctamente
CMD ["sh", "-c", "php artisan config:cache && php artisan route:cache && php artisan view:cache && php artisan octane:start --server=swoole --host=0.0.0.0 --port=9000"]