FROM php:8.3-apache

WORKDIR /var/www/html

RUN apt-get update \
    && apt-get install -y libpq-dev \
    && docker-php-ext-install pdo pdo_pgsql \
    && rm -rf /var/lib/apt/lists/*

COPY index.php /var/www/html/index.php


