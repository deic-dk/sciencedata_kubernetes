<?php

// curl '10.0.0.12/set_allowed_ips.php?user_id=fror@dtu.dk&pod=ubuntu-focal-fror-dtu-dk&ips='

if(strpos($_SERVER['REMOTE_ADDR'], '10.0')!==0){
	header($_SERVER['SERVER_PROTOCOL'] . " 403 Forbidden", true, 403);
	exit;
}

$_GET = array_map(function($x){return escapeshellcmd($x);}, $_GET);

$owner = $_GET['user_id']; // ID of the user logged into ScienceData
$pod = $_GET['pod']; // Name of the pod
$https_port = $_GET['https_port']; // HTTPS port
$ssh_port = $_GET['ssh_port']; // SSH port
$extra_ports = $_GET['extra_ports']; // SSH ports

$output = null;
$retval = null;

if(empty($owner) || empty($pod) || empty($owner)){
	header($_SERVER['SERVER_PROTOCOL'] . " 403 Forbidden", true, 403);
	echo "<h1>Missing parameter(s)!</h1>";
	exit;
}

exec('export KUBECONFIG=/etc/kubernetes/admin.conf; set_port_numbers -u "'.$owner.'"  -w "'.$https_port.'" -s "'.$ssh_port.'" -x "'.$extra_ports.'" "'.$pod.'"', $output, $retval);

if($retval===0){
	echo "{\"data\":{\"name\":\"$pod\", ".
			"\"message\":\"OK\"}, ".
			"\"status\":\"success\"}";
}
else{
	header($_SERVER['SERVER_PROTOCOL'] . " 500 Internal Server Error", true, 500);
	echo "{\"data\":{\"error\": \"".implode(", ", $output)."\", ".
									"\"message\":\"Something went wrong...\"}, ".
				"\"status\":\"error\"}";
}

?>
