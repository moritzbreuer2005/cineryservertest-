#!/bin/sh
# Laeuft bei jedem Start (idempotent): user_oidc installieren + Keycloak als Provider eintragen.
set -e
occ() {
  if [ "$(id -u)" = 0 ]; then
    su -s /bin/sh www-data -c "php /var/www/html/occ $*"
  else
    php /var/www/html/occ "$@"
  fi
}

occ config:system:set allow_local_remote_servers --value=true --type=bool
# user_oidc verlangt HTTPS, ausser im Debug-Modus -> nur fuer lokale http-URLs aktivieren
case "$NC_URL" in
  http://*) occ config:system:set debug --value=true --type=bool ;;
  *)        occ config:system:set debug --value=false --type=bool ;;
esac
occ app:install user_oidc 2>/dev/null || true
occ app:enable user_oidc

occ user_oidc:provider keycloak \
  --clientid="$OIDC_CLIENT_ID" \
  --clientsecret="$OIDC_CLIENT_SECRET" \
  --discoveryuri="$OIDC_DISCOVERY_URI" \
  --scope="openid email profile" \
  --unique-uid=0 \
  --mapping-uid=preferred_username \
  --mapping-display-name=name \
  --mapping-email=email \
  --mapping-groups=groups \
  --group-provisioning=1 \
  --send-id-token-hint=1
