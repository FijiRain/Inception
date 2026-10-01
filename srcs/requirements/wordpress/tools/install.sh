#!/bin/sh
set -e

apt-get update
apt-get install -y php-fpm php-mysql php-curl php-gd php-xml php-mbstring curl mariadb-client

curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x /usr/local/bin/wp