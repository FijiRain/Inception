#!/bin/sh
set -e # kill script if a command fails

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld # to change the file owner

sed -i "s/bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf # listen on all interfaces

MYSQL_PASSWORD=$(cat /run/secrets/db_password) # get the passwords
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password) 
MYSQL_ADMIN_PASSWORD=$(grep "WP_ADMIN_PASSWORD" /run/secrets/credentials | cut -d'=' -f2)

MYSQL_USER="${MYSQL_USER}"
MYSQL_ADMIN_USER="${MYSQL_ADMIN_USER}"

# Check if there are no errors or not missing fields
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD is empty}"
: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is empty}"
: "${MYSQL_ADMIN_PASSWORD:?MYSQL_ADMIN_PASSWORD is empty}"
: "${MYSQL_USER:?MYSQL_USER is empty}"
: "${MYSQL_ADMIN_USER:?MYSQL_ADMIN_USER is empty}"

# check if the original file exists 
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
    mysqld --user=mysql &
    until mysqladmin ping > /dev/null 2>&1; do
        sleep 1
    done

	# SQL command that runs until we reach EOF
    mysql << EOF
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON wordpress.* TO '${MYSQL_USER}'@'%';

CREATE USER IF NOT EXISTS '${MYSQL_ADMIN_USER}'@'%' IDENTIFIED BY '${MYSQL_ADMIN_PASSWORD}';
GRANT ALL PRIVILEGES ON wordpress.* TO '${MYSQL_ADMIN_USER}'@'%';

DELETE FROM mysql.user WHERE User='';

ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

FLUSH PRIVILEGES;
EOF
    mysqladmin shutdown -uroot -p"${MYSQL_ROOT_PASSWORD}"
fi

exec mysqld --user=mysql # user that we find at the beginning of the script
