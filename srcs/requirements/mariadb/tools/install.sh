#!/bin/sh
set -e
apt-get update
apt-get install -y mariadb-server
rm -rf /var/lib/mysql/*