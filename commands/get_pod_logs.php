<?php


if(strpos($_SERVER['REMOTE_ADDR'], '10.0')!==0){
	header($_SERVER['SERVER_PROTOCOL'] . " 403 Forbidden", true, 403);
	exit;
}

$_GET = array_map(function($x){return escapeshellcmd($x);}, $_GET);

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
	$output = [];
	$ret = "";
	exec('export KUBECONFIG=/etc/kubernetes/admin.conf; get_pod_logs -u "'.$owner.'" "'.$pod.'"', $output, $ret);
	if($ret==0){
		echo implode("\n", $output);
	}
	else{
		header($_SERVER['SERVER_PROTOCOL'] . " 500 Internal Server Error", true, 500);
		echo "{\"data\":{\"message\":\"Could not get pod log\"}, ".
			"\"status\":\"error\"}";
		exit;
	}
}
?>
