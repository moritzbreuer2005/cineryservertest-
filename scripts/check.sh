#!/usr/bin/env bash
# Prueft, ob alle drei Dienste erreichbar sind und die OIDC-Verbindung steht.
#   ./scripts/check.sh          einmalige Pruefung
#   ./scripts/check.sh --wait   wartet bis alles bereit ist (max. 10 Min)
set -uo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a
KC_URL=$(eval echo "$KC_URL"); NC_URL=$(eval echo "$NC_URL"); WP_URL=$(eval echo "$WP_URL")
PORT=${HTTP_PORT:-80}
curl_() { curl -s --max-time 10 --resolve "auth.$BASE_DOMAIN:$PORT:127.0.0.1" \
  --resolve "cloud.$BASE_DOMAIN:$PORT:127.0.0.1" --resolve "wp.$BASE_DOMAIN:$PORT:127.0.0.1" "$@"; }
DISCOVERY="$KC_URL/realms/$KC_REALM/.well-known/openid-configuration"

run_checks() {
  local fail=0
  ok() { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
  no() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=1; }

  curl_ -f "$DISCOVERY" | grep -q "\"issuer\":\"$KC_URL/realms/$KC_REALM\"" \
    && ok "Keycloak: Discovery + Issuer ($KC_URL)" || no "Keycloak: Discovery/Issuer"
  curl_ -f "$NC_URL/status.php" | grep -q '"installed":true' \
    && ok "Nextcloud: installiert ($NC_URL)" || no "Nextcloud: status.php"
  curl_ -f -o /dev/null -L "$WP_URL/wp-login.php" \
    && ok "WordPress: erreichbar ($WP_URL)" || no "WordPress: wp-login.php"

  docker compose exec -T nextcloud php -r "exit(@file_get_contents('$DISCOVERY')?0:1);" \
    && ok "Nextcloud-Container erreicht Keycloak" || no "Nextcloud-Container -> Keycloak"
  docker compose exec -T -u www-data nextcloud php occ user_oidc:provider keycloak 2>/dev/null | grep -q "$KC_REALM" \
    && ok "Nextcloud: OIDC-Provider 'keycloak' konfiguriert" || no "Nextcloud: OIDC-Provider"
  docker compose exec -T wordpress php -r "exit(@file_get_contents('$DISCOVERY')?0:1);" \
    && ok "WordPress-Container erreicht Keycloak" || no "WordPress-Container -> Keycloak"
  docker compose exec -T db mariadb -N -uwordpress -p"$DB_PASSWORD" wordpress -e "SELECT option_value FROM wp_options WHERE option_name='openid_connect_generic_settings'" 2>/dev/null | grep -q "$KC_REALM" \
    && ok "WordPress: OIDC-Plugin konfiguriert" || no "WordPress: OIDC-Plugin"
  return $fail
}

if [ "${1:-}" = "--wait" ]; then
  for i in $(seq 1 60); do
    run_checks >/dev/null 2>&1 && break
    sleep 10
  done
fi
run_checks
