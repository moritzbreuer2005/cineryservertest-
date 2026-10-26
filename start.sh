#!/usr/bin/env bash
# Erststart: .env mit Zufalls-Secrets erzeugen, Stack hochfahren, URLs + Logins ausgeben.
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  rnd() { LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24; }
  cp .env.example .env
  for key in KC_ADMIN_PASSWORD NEXTCLOUD_CLIENT_SECRET WORDPRESS_CLIENT_SECRET NC_ADMIN_PASSWORD \
             WP_ADMIN_PASSWORD DB_ROOT_PASSWORD DB_PASSWORD; do
    sed -i.bak "s|^$key=change-me|$key=$(rnd)|" .env
  done
  rm -f .env.bak
  echo ".env mit Zufalls-Secrets erzeugt."
fi

docker compose up -d
echo "Warte auf Keycloak, Nextcloud und WordPress (erster Start: 2-4 Minuten) ..."
./scripts/check.sh --wait

set -a; . ./.env; set +a
cat <<MSG

  Keycloak   $(eval echo "$KC_URL")   (Admin: $KC_ADMIN_USER / $KC_ADMIN_PASSWORD)
  Nextcloud  $(eval echo "$NC_URL")   (lokaler Admin: $NC_ADMIN_USER / $NC_ADMIN_PASSWORD, Direktlogin: /login?direct=1)
  WordPress  $(eval echo "$WP_URL")/wp-login.php   (lokaler Admin: $WP_ADMIN_USER / $WP_ADMIN_PASSWORD)

  SSO-Demo-User (Passwort: $DEMO_PASSWORD):
    alice  Gruppe admin    -> Nextcloud-Admin, WordPress-Administrator
    bob    Gruppe editors  -> Nextcloud-Gruppe editors, WordPress-Editor
    carol  Gruppe members  -> Nextcloud-Gruppe members, WordPress-Subscriber
MSG
