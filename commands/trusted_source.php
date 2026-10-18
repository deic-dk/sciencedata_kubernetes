<?php

/**
 * Shared source-address gate for the kube commands (run_pod, get_containers,
 * delete_pod, get_pod_logs, set_allowed_ips, set_port_numbers).
 *
 * Callers are either ScienceData servers on the 10.0 management net, or the
 * Nextcloud test silos, which are pods on the 10.2 pod net. User pods are on
 * 10.2 too and must be kept out, so the test silos are admitted by address:
 * resolved live from kubernetes as the pods named nextcloud-dev-* that are
 * OWNED BY AN ADMIN ($admins below; run_pod stamps the owner into the user/domain
 * labels at creation, so a nextcloud_dev pod started by anyone else is not trusted).
 * That survives pod restarts and new test silos; the static list is only a
 * fallback for when kubectl is unavailable. Requires that pod->kube HTTP is
 * NOT masqueraded on the worker nodes (sciencedata_bridge.sh's RETURN rule),
 * otherwise every pod on a node arrives as that node's 10.0 address and
 * passes as a server.
 */

$test_pods_ips_fallback = ['10.2.164.63', '10.2.24.64', '10.2.164.64'];
$test_pods_name_prefix = 'nextcloud-dev-';
// The admins: may run arbitrary manifests (run_pod.php) and own the test silos. The ONE place this is defined.
$admins = ['cloud', 'fror@dtu.dk'];

function sciencedata_test_pods_ips(): array {
	global $test_pods_ips_fallback, $test_pods_name_prefix;
	$cache = sys_get_temp_dir() . '/sciencedata_test_pods_ips.json';
	if (is_file($cache) && time() - filemtime($cache) < 60) {
		$ips = json_decode((string)file_get_contents($cache), true);
		if (is_array($ips)) {
			return $ips;
		}
	}
	global $admins;
	$out = shell_exec('KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods --no-headers ' .
		'-o custom-columns=NAME:.metadata.name,IP:.status.podIP,USER:.metadata.labels.user,DOMAIN:.metadata.labels.domain 2>/dev/null');
	$ips = [];
	foreach (preg_split('/\R/', (string)$out) as $line) {
		$f = preg_split('/\s+/', trim($line));
		if (count($f) !== 4 || strpos($f[0], $test_pods_name_prefix) !== 0 || !filter_var($f[1], FILTER_VALIDATE_IP)) {
			continue;
		}
		$owner = $f[2] . ($f[3] === '<none>' || $f[3] === '' ? '' : '@' . $f[3]);
		if (in_array($owner, $admins, true)) {
			$ips[] = $f[1];
		}
	}
	if (empty($ips)) {
		return $test_pods_ips_fallback;
	}
	@file_put_contents($cache, json_encode($ips), LOCK_EX);
	return $ips;
}

function sciencedata_is_test_pod(string $ip): bool {
	return in_array($ip, sciencedata_test_pods_ips(), true);
}

/** True for a ScienceData server (10.0.x.y) or a Nextcloud test silo pod. */
function sciencedata_trusted_source(string $ip): bool {
	return $ip !== '' && (strpos($ip, '10.0.') === 0 || sciencedata_is_test_pod($ip));
}

/** Reject the request with 403 unless it comes from a trusted source. */
function sciencedata_require_trusted_source(): void {
	$ip = (string)($_SERVER['REMOTE_ADDR'] ?? '');
	if (!sciencedata_trusted_source($ip)) {
		empty($_SERVER['SERVER_PROTOCOL']) ?: header($_SERVER['SERVER_PROTOCOL'] . " 403 Forbidden", true, 403);
		exit;
	}
}
