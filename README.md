# Kube: The ScienceData Kubernetes service

The ScienceData Kubernetes service allows ScienceData users to conveniently process data off their ScienceData storage.

This repository contains manifests and utilities used for providing the service on the Kube servers. These rely on the services exposed by the ScienceData master server and data silos.

- Pods/containers can be started directly from the ScienceData web interface
- A basic collection of pod manifests is provided
- Users can extend this, using the huge collection of image from Docker Hub
- Users can curl data directly from/to their ScienceData home directory over a trusted/direct connection w/o username/password
- Users can log in to their containers via SSH with their private SSH key after uploading their public key
- A website/service running in a pod, on port 80, is inverse-proxied by https://kube.sciencedata.dk:PORT_NUMBER/
- Persistent storage is mounted via NFSv4.1 from the ScienceData home server

## Try it out (admin only)

```
run_pod -o testuser@dtu.dk -p www sciencedata_kubernetes/pod_manifests/ubuntu_sciencedata.yaml
```
```
get_containers
```
```
delete_pod ubuntu-focal-testuser-dtu-dk
```

## Try it out (user)