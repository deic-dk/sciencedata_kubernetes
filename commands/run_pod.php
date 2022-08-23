<?php

$logFile = "/var/log/kube.log";
$admins = ['cloud', 'fror@dtu.dk', 'jodac@dtu.dk'];

// curl '10.0.0.12/run_pod.php?user_id=fror@dtu.dk&storage_path=www&public_key=ssh-rsa%20AAAAB3NzaC1yc2EAAAABIwAAAIEA1lUNAcCuUvl2nxu0ILt0zfdESUmOGlktcDbv8ufRcJ6A1oYDksn%2BFHxxWU3X7laD7dfF9BBkLr5nC3M7ZuuoW1j2QcHcdFRSfTSLuSYM%2FebHdR5g65gGJWrc8qCaFEWS2unLz6rbCqtKBscQDsLtosIXx1brOmWFATWm%2FuCvABc%3D%20frederik%40pcitapi34&yaml_uri=/files/tmp/ubuntu_sciencedata.yaml'

if(strpos($_SERVER['REMOTE_ADDR'], '10.0')!==0){
	header($_SERVER['SERVER_PROTOCOL'] . " 403 Forbidden", true, 403);
	exit;
}

$owner = $_GET['user_id']; // ID of the user logged into ScienceData and starting the pod
$storage_path = empty($_GET['storage_path'])?"":$_GET['storage_path']; // Path to mount relative to the URI /storage/
$public_key = empty($_GET['public_key'])?"":$_GET['public_key']; // SSH public key of the user
$file = empty($_GET['file'])?"":$_GET['file']; // File top open inside pod
$yaml_url = $_GET['yaml_url']; // URL of the YAML file to apply - read using the supplied user ID if it starts with
															// /shared/, /files/, /group/, /sharingin/, /storage/, otherwise read with admin privileges (system/app file).

if(empty($owner) || empty($yaml_url)){
	header($_SERVER['SERVER_PROTOCOL'] . " 500 Internal Server Error", true, 500);
	echo "<h1>Missing parameter(s)!</h1>";
	exit;
}

$output = null;
$retval = null;
$server_ip = $_SERVER['REMOTE_ADDR'];

// Only trusted service accounts are allowed to run arbitrary yaml
if(in_array($owner, $admins){
	// If it's a path/URI, assume it's on the originating silo and prepend its URL
	$yaml_url = ltrim($yaml_url, "/");
	if(strpos($yaml_url, "shared")===0 || strpos($yaml_url, "files")===0 || strpos($yaml_url, "group")===0 || strpos($yaml_url, "sharingin")===0 || strpos($yaml_url, "storage")===0){
		$server_ip = urlencode($owner).'@'.$server_ip;
	}
	if(strpos($yaml_url, "https://")===false){
		$yaml_url = "https://".$server_ip.'/'.$yaml_url;
	}
}
else{
	// make sure the manifest is hosted in our repo on github
	$official_yaml_regex = '/https:\/\/raw[.]githubusercontent[.]com\/deic-dk\/pod_manifests.*/';
	if(!preg_match($official_yaml_regex, $yaml_url)){
		echo "<h1>Error. Missing or forbidden yaml</h1>";
		exit;
	}
}

$arrContextOptions=array(
	"ssl"=>array(
		"verify_peer"=>false,
		"verify_peer_name"=>false,
	),
);

$yaml = file_get_contents($yaml_url, false, stream_context_create($arrContextOptions));
$tmpfile = tmpfile();
fwrite($tmpfile, $yaml);
$metadata = stream_get_meta_data($tmpfile);
$tmpfile_name = $metadata['uri'];

$cmd = '/bin/bash -c \'set -o pipefail;' . // use bash with pipefail so the error code from run_pod gets propagated
	'export KUBECONFIG=/etc/kubernetes/admin.conf;' . // use kubernetes config
	(empty($file) ? '' : ' export FILE=' . escapeshellarg($file) . ';') .
	' run_pod "$@" 2>&1 | tee -a "' . $logFile . '"\' --' . // call run_pod with all subsequent arguments, pass stdout/err to append the log
	' -o ' . escapeshellarg($owner) .
	' -s ' . escapeshellarg($_SERVER['REMOTE_ADDR']) .
	' -k ' . escapeshellarg($public_key) .
	' -r ' . escapeshellarg($storage_path) .
	' ' . escapeshellarg($tmpfile_name);

exec($cmd, $output, $retval);
fclose($tmpfile);

$success_match = preg_grep('/^SUCCESS:.*$/', $output);
// If okay, then send an http 200 OK with the name of the starting pod
if($retval===0 && count($success_match) > 0){
	$pod_name = str_replace("SUCCESS: ", "", $success_match[0]);
	echo "<h1>OK</h1>";
	echo "<pre>".$pod_name."</pre>";
}
else{
	header($_SERVER['SERVER_PROTOCOL'] . " 500 Internal Server Error", true, 500);
	echo "<h1>Something went wrong with $cmd! Check existence of $yaml_url</h1>";
	echo "<pre>".implode("\n", $output)."</pre>";
}

