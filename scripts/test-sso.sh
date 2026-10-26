#!/usr/bin/env bash
# End-to-End-Test: loggt jeden Demo-User per OIDC in Nextcloud und WordPress ein
# (Authorization-Code-Flow ueber Keycloaks Login-Formular) und prueft die uebernommenen Rechte.
set -uo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a
NC_URL=$(eval echo "$NC_URL"); WP_URL=$(eval echo "$WP_URL")
fail=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# sso_login <start-url> <user> -> gibt die End-URL aus
sso_login() {
  local jar="$tmp/jar.$RANDOM" page action
  page=$(curl -s -L -c "$jar" -b "$jar" "$1")
  action=$(printf '%s' "$page" | grep -o 'action="[^"]*"' | head -1 | sed 's/action="//;s/"$//;s/&amp;/\&/g')
  [ -n "$action" ] || { echo "kein Keycloak-Formular"; return 1; }
  curl -s -L -c "$jar" -b "$jar" -o /dev/null -w '%{url_effective}' \
    --data-urlencode "username=$2" --data-urlencode "password=$DEMO_PASSWORD" "$action"
}
check() { # check <label> <expected> <actual>
  if [ "$2" = "$3" ]; then printf '  \033[32mOK\033[0m   %s = %s\n' "$1" "$3"
  else printf '  \033[31mFAIL\033[0m %s: erwartet "%s", erhalten "%s"\n' "$1" "$2" "$3"; fail=1; fi
}
dbq() { docker compose exec -T db mariadb -N -uwordpress -p"$DB_PASSWORD" wordpress -e "$1" 2>/dev/null; }
occ() { docker compose exec -T -u www-data nextcloud php occ "$@" 2>/dev/null; }

for user in alice bob carol; do
  case $user in alice) role=administrator; ncgroup=admin;; bob) role=editor; ncgroup=editors;; carol) role=subscriber; ncgroup=members;; esac
  echo "== $user"
  end=$(sso_login "$NC_URL/apps/user_oidc/login/1" "$user")
  check "Nextcloud-Login (Endseite)" "$NC_URL/apps/dashboard/" "$end"
  check "Nextcloud-Gruppen" "$ncgroup" "$(occ user:info "$user" --output=json | python3 -c 'import sys,json;print(",".join(json.load(sys.stdin)["groups"]))')"
  wpstart=$(curl -s "$WP_URL/wp-login.php" | grep -o 'http://auth[^"]*client_id=wordpress[^"]*' | head -1 | sed 's/&amp;/\&/g')
  end=$(sso_login "$wpstart" "$user")
  case "$end" in "$WP_URL"/wp-admin*|"$WP_URL"/) ok=eingeloggt;; *) ok="$end";; esac
  check "WordPress-Login" "eingeloggt" "$ok"
  check "WordPress-Rolle" "$role" "$(dbq "select m.meta_value from wp_users u join wp_usermeta m on m.user_id=u.ID and m.meta_key='wp_capabilities' where u.user_login='$user'" | grep -o '"[a-z]*"' | head -1 | tr -d '"')"
done
exit $fail
