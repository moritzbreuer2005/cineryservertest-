<?php
/**
 * Plugin Name: OIDC Role Map
 * Description: Setzt bei jedem OIDC-Login die WordPress-Rolle aus dem "groups"-Claim (Keycloak ist Source of Truth).
 *
 * Konfiguration per Umgebungsvariable:
 *   OIDC_ROLE_MAP     "gruppe=rolle,gruppe2=rolle2" – erste passende Gruppe gewinnt (hoechste Rechte zuerst)
 *   OIDC_DEFAULT_ROLE Rolle, wenn keine Gruppe passt (Default: subscriber)
 */

function oidc_role_map_sync($user, $claim) {
	if (!($user instanceof WP_User) || !is_array($claim)) {
		return;
	}
	$groups = isset($claim['groups']) && is_array($claim['groups']) ? $claim['groups'] : [];
	$groups = array_map(fn($g) => ltrim((string) $g, '/'), $groups);

	$role = getenv('OIDC_DEFAULT_ROLE') ?: 'subscriber';
	foreach (explode(',', getenv('OIDC_ROLE_MAP') ?: '') as $pair) {
		[$group, $mapped] = array_pad(array_map('trim', explode('=', $pair, 2)), 2, '');
		if ($group !== '' && $mapped !== '' && in_array($group, $groups, true)) {
			$role = $mapped;
			break;
		}
	}

	if (get_role($role) && !in_array($role, (array) $user->roles, true)) {
		$user->set_role($role);
	}
}

add_action('openid-connect-generic-user-create', 'oidc_role_map_sync', 10, 2);
add_action('openid-connect-generic-update-user-using-current-claim', 'oidc_role_map_sync', 10, 2);
