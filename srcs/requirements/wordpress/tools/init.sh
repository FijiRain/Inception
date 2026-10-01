#!/bin/sh
set -e

# Lecture des variables
MYSQL_PASSWORD=$(cat /run/secrets/db_password)
MYSQL_USER="${MYSQL_USER}"
MYSQL_DATABASE="${MYSQL_DATABASE}"
WP_ADMIN_USER=$(grep "WP_ADMIN_USER" /run/secrets/credentials | cut -d'=' -f2)
WP_ADMIN_PASSWORD=$(grep "WP_ADMIN_PASSWORD" /run/secrets/credentials | cut -d'=' -f2)
DOMAIN_NAME="${DOMAIN_NAME}"
WP_USER=$(grep "WP_USER=" /run/secrets/credentials | cut -d'=' -f2)
WP_USER_PASSWORD=$(grep "WP_USER_PASSWORD" /run/secrets/credentials | cut -d'=' -f2)

# Verification des variables pour eviter erreurs
: "${MYSQL_USER:?MYSQL_USER is empty}"
: "${MYSQL_DATABASE:?MYSQL_DATABASE is empty}"
: "${DOMAIN_NAME:?DOMAIN_NAME is empty}"
: "${WP_ADMIN_USER:?WP_ADMIN_USER is empty}"
: "${WP_ADMIN_PASSWORD:?WP_ADMIN_PASSWORD is empty}"
: "${WP_USER:?WP_USER is empty}"
: "${WP_USER_PASSWORD:?WP_USER_PASSWORD is empty}"

# Verification du nom d'admin conformemement au sujet
if echo "${WP_ADMIN_USER}" | grep -qi "admin"; then
    echo "Error: WP_ADMIN_USER must not contain 'admin'" >&2
    exit 1
fi

# Initialisation de WP au premier démarrage
if [ ! -f "/var/www/wordpress/.wp_good_init" ]; then
    mkdir -p /var/www/wordpress
    cp -r /usr/src/wordpress/. /var/www/wordpress/

    until mysqladmin ping -h mariadb -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --silent >/dev/null 2>&1; do
        sleep 2
    done

    wp config create \
        --path=/var/www/wordpress \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="mariadb" \
        --allow-root

    wp core install \
        --path=/var/www/wordpress \
        --url="${DOMAIN_NAME}" \
        --title="Inception" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="admin@${DOMAIN_NAME}" \
        --allow-root

    wp user create "${WP_USER}" "user@${DOMAIN_NAME}"\
        --user_pass="${WP_USER_PASSWORD}" \
        --role=author \
        --path=/var/www/wordpress \
        --allow-root

    touch /var/www/wordpress/.wp_good_init
fi

# Verif que user a été créé ET admin aussi
if ! wp user get "${WP_ADMIN_USER}" --path=/var/www/wordpress --allow-root >/dev/null 2>&1; then
    echo "Error: WP_ADMIN_USER (${WP_ADMIN_USER}) was not created" >&2
    exit 1
fi

if ! wp user get "${WP_USER}" --path=/var/www/wordpress --allow-root >/dev/null 2>&1; then
    echo "Error: WP_USER (${WP_USER}) was not created" >&2
    exit 1
fi

mkdir -p /run/php
exec php-fpm8.2 -F
