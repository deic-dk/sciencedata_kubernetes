<?php

// curl '10.0.0.12/delete_pod.php?user_id=fror@dtu.dk&pod=ubuntu-focal-fror-dtu-dk'

require_once __DIR__ . '/trusted_source.php';
sciencedata_require_trusted_source();

$_GET = array_map(function($x){return escapeshellcmd($x);}, $_GET);

$owner = $_GET['user_id']; // ID of the user logged into ScienceData
$pod = $_GET['pod']; // Name of the pod

$output = null;
$retval = null;

if(empty($owner) || empty($pod)){
	header($_SERVER['SERVER_PROTOCOL'] . " 403 Forbidden", true, 403);
	echo "<h1>Missing parameter(s)!</h1>";
	exit;
}

exec('export KUBECONFIG=/etc/kubernetes/admin.conf; delete_pod -u "'.$owner.'" "'.$pod.'"', $output, $retval);

if($retval===0){
	echo "{\"data\":{\"name\":\"$pod\", ".
			"\"message\":\"OK\"}, ".
			"\"status\":\"success\"}";
}
else{
	header($_SERVER['SERVER_PROTOCOL'] . " 500 Internal Server Error", true, 500);
	echo "{\"data\":{\"error\": \"".$output."\", ".
									"\"message\":\"Something went wrong...\"}, ".
				"\"status\":\"error\"}";
}

?>
