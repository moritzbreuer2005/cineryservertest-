#!/bin/sh
# Legt je Anwendung eine eigene Datenbank + Benutzer an (nur beim ersten Start).
set -e
for app in keycloak nextcloud wordpress; do
  mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" <<SQL
CREATE DATABASE IF NOT EXISTS \`$app\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$app'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$app\`.* TO '$app'@'%';
SQL
done
