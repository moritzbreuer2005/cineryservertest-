# local-sso – Keycloak + Nextcloud + WordPress

Lokaler Entwicklungs-Stack: **Keycloak** ist das zentrale IAM, **Nextcloud** und **WordPress**
melden sich per OpenID Connect daran an. Rechte werden in Keycloak über *Gruppen* gesetzt und
in beiden Anwendungen automatisch übernommen.

## Start

```bash
./start.sh        # erzeugt .env mit Zufalls-Secrets, startet alles, gibt URLs + Logins aus
./scripts/check.sh      # prüft Erreichbarkeit + OIDC-Verbindung jederzeit erneut
./scripts/test-sso.sh   # End-to-End: loggt alice/bob/carol in Nextcloud + WordPress ein und prüft Gruppen/Rollen
docker compose down      # stoppen (Daten bleiben)   |   down -v = alles löschen
```

Voraussetzung: Docker mit Compose v2 (macOS: `brew install colima docker docker-compose && colima start --cpu 4 --memory 6`). Erster Start dauert wegen Image-Downloads und
Plugin-Installation (user_oidc, OpenID Connect Generic) einige Minuten.

| Dienst | URL (Default) |
|---|---|
| Keycloak | http://auth.localtest.me |
| Nextcloud | http://cloud.localtest.me |
| WordPress | http://wp.localtest.me |

## Rechte-Modell

Keycloak-Gruppen → Claim `groups` → Anwendung:

| Keycloak-Gruppe | Nextcloud | WordPress |
|---|---|---|
| `admin` | Gruppe `admin` = Nextcloud-Admin | Administrator |
| `editors` | Gruppe `editors` | Editor |
| `members` (Default für neue User) | Gruppe `members` | Subscriber |

* Nextcloud: `user_oidc` mit Group-Provisioning (Gruppen werden angelegt, Mitgliedschaft bei jedem Login synchronisiert).
* WordPress: `wordpress/mu-plugins/oidc-role-map.php` setzt die Rolle bei jedem Login. Mapping per
  `OIDC_ROLE_MAP` in `.env` (hoechste Rechte zuerst), Fallback `OIDC_DEFAULT_ROLE`.
* Neue Gruppen/User: in Keycloak anlegen (Realm `local`) – oder `keycloak/realm.json` erweitern
  (wird nur beim **ersten** Start importiert; danach in der Admin-Konsole pflegen).
* Single Logout: Nextcloud per Back-Channel, WordPress per Redirect auf Keycloaks Logout (konfiguriert, nicht end-to-end getestet).

## Anpassen

Alles in `.env` (Vorlage `.env.example`): Domain (`BASE_DOMAIN`), Port
(`HTTP_PORT` + `URL_PORT=:8080`), Versionen, Realm-Name, Passwörter, Rollen-Mapping.
Hinweis: `*.localhost` funktioniert **nicht** (libcurl löst es intern auf Loopback auf), daher `localtest.me` (zeigt öffentlich auf 127.0.0.1, braucht Internet-DNS).
Wichtig: Browser und Container nutzen dieselbe URL (der Proxy hat im Docker-Netz die Aliase
`auth.*`, `cloud.*`, `wp.*`) – dadurch stimmt der OIDC-Issuer überall.

## Später anbinden (APIs / Automation)

| Dienst | Schnittstelle | Zugang |
|---|---|---|
| Keycloak | Admin-REST `http://auth.localtest.me/admin/realms/local` | Master-Admin aus `.env`, Token via `admin-cli` |
| Nextcloud | OCS/WebDAV `http://cloud.localtest.me/ocs/v2.php`, `/remote.php/dav` | App-Passwort des Admins (Einstellungen → Sicherheit) |
| WordPress | REST `http://wp.localtest.me/wp-json` | Application Password (Profil des Admins) |

Für eine echte Umgebung: `KC_URL`/`NC_URL`/`WP_URL` und `BASE_DOMAIN` anpassen, HTTPS am Proxy
terminieren, `start-dev` in `compose.yaml` durch `start` ersetzen und Secrets neu setzen.

> Nur für lokale Entwicklung: HTTP, Dev-Modus, Demo-User.
