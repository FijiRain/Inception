#!/bin/sh
set -e # si une commande échoue, le script s'arrête

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld # pour changer le proprio du fichier

sed -i "s/bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf

MYSQL_PASSWORD=$(cat /run/secrets/db_password) # recup les mdp
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password) 
MYSQL_ADMIN_PASSWORD=$(grep "WP_ADMIN_PASSWORD" /run/secrets/credentials | cut -d'=' -f2)

MYSQL_USER="${MYSQL_USER}"
MYSQL_ADMIN_USER="${MYSQL_ADMIN_USER}"

# Pour voir s'il manque pas une info ou si y'a pas d'erreur
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD is empty}"
: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is empty}"
: "${MYSQL_ADMIN_PASSWORD:?MYSQL_ADMIN_PASSWORD is empty}"
: "${MYSQL_USER:?MYSQL_USER is empty}"
: "${MYSQL_ADMIN_USER:?MYSQL_ADMIN_USER is empty}"

# Verif que le fichier de base existe ou pas
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
    mysqld --user=mysql &
    until mysqladmin ping > /dev/null 2>&1; do
        sleep 1
    done

	# commande SQL qui se rentrent tant que pas EOF
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

exec mysqld --user=mysql # user qu'on retrouve au début du script
