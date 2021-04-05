<?php

// curl '10.0.0.12/get_containers.php?user_id=fror@dtu.dk'

if(strpos($_SERVER['REMOTE_ADDR'], '10.0')!==0){
	header($_SERVER['SERVER_PROTOCOL'] . " 403 Forbidden", true, 403);
	exit;
}

$owner = $_GET['user_id']??""; // ID of the user logged into ScienceData
$fields = $_GET['fields']; // Get just the fields

if(empty($fields)){
	/*header($_SERVER['SERVER_PROTOCOL'] . " 403 Forbidden", true, 403);
	echo "<h1>Missing parameter(s)!</h1>";
	exit;*/
	echo `export KUBECONFIG=/etc/kubernetes/admin.conf; get_containers "$owner"`;
}
else{
	// TODO: not very efficient. Consider adding flags to script.
	echo `export KUBECONFIG=/etc/kubernetes/admin.conf; get_containers "$owner" 2>&1 | head -2 | tail -1`;
}

?>
