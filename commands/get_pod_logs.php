<?php


if(strpos($_SERVER['REMOTE_ADDR'], '10.0')!==0){
	header($_SERVER['SERVER_PROTOCOL'] . " 403 Forbidden", true, 403);
	exit;
}

$owner = $_GET['user_id']; // ID of the user logged into ScienceData
$pod = $_GET['pod']; // Name of the pod

$output = null;
$retval = null;

if(empty($owner) || empty($pod)){
	header($_SERVER['SERVER_PROTOCOL'] . " 403 Forbidden", true, 403);
	echo "{\"data\":{\"message\":\"Missing owner or pod name\"}, ".
				"\"status\":\"error\"}";
	exit;
}
else{
	echo `export KUBECONFIG=/etc/kubernetes/admin.conf; get_pod_logs -u "$owner" "$pod"`;
}
?>
