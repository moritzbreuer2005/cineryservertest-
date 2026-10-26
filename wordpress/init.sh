#!/bin/sh
# Einmal-Job: WordPress installieren, OIDC-Plugin installieren und gegen Keycloak konfigurieren.
set -e
cd /var/www/html

echo "[wp-init] warte auf WordPress-Dateien und Datenbank ..."
until [ -f wp-config.php ] && wp db query "SELECT 1" >/dev/null 2>&1; do sleep 3; done

if ! wp core is-installed 2>/dev/null; then
  wp core install --url="$WP_URL" --title="Local WordPress" \
    --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASSWORD" \
    --admin_email="$WP_ADMIN_EMAIL" --skip-email
fi

wp plugin is-installed daggerhart-openid-connect-generic || wp plugin install daggerhart-openid-connect-generic
wp plugin activate daggerhart-openid-connect-generic

OIDC="$KC_ISSUER/protocol/openid-connect"
wp option update openid_connect_generic_settings "$(cat <<JSON
{
  "login_type": "button",
  "login_button_text": "Mit Keycloak anmelden",
  "client_id": "$OIDC_CLIENT_ID",
  "client_secret": "$OIDC_CLIENT_SECRET",
  "scope": "openid email profile",
  "endpoint_login": "$OIDC/auth",
  "endpoint_userinfo": "$OIDC/userinfo",
  "endpoint_token": "$OIDC/token",
  "endpoint_end_session": "$OIDC/logout",
  "endpoint_jwks": "$OIDC/certs",
  "issuer": "$KC_ISSUER",
  "identity_key": "preferred_username",
  "nickname_key": "preferred_username",
  "email_format": "{email}",
  "displayname_format": "{name}",
  "identify_with_username": "1",
  "no_sslverify": "0",
  "http_request_timeout": "10",
  "enforce_privacy": "0",
  "alternate_redirect_uri": "0",
  "token_refresh_enable": "1",
  "link_existing_users": "0",
  "create_if_does_not_exist": "1",
  "redirect_user_back": "1",
  "redirect_on_logout": "1",
  "enable_logging": "0",
  "log_limit": "1000"
}
JSON
)" --format=json

echo "[wp-init] fertig."
