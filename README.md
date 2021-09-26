# The ScienceData Kubernetes service

This repository provides a supporting service for the ScienceData/ownCloud/Nextcloud app [user_pods](https://github.com/deic-dk/user_pods). The ScienceData Kubernetes service allows ScienceData users to conveniently process data off their ScienceData storage from their pods.

This repository contains manifests and utilities allowing the Kubernetes control plane servers to provide the service. These, in turn, rely on the services exposed by the ScienceData master server and data silos.

- Pods/containers can be started directly from the ScienceData [web interface](https://github.com/deic-dk/user_pods)
- A basic collection of pod manifests and associated images is provided, hosted on [GitHub](https://github.com/deic-dk/pod_manifests) and [Docker Hub](https://hub.docker.com/u/sciencedata) respectively
- Users are encouraged to add to this collection by extending the provided images or using the huge collection of images from Docker Hub
- Users can curl data directly from/to the "Home" directory on their ScienceData home server, with IP address "sciencedata" over a trusted/direct connection w/o username/password
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

See [user_pods](https://github.com/deic-dk/user_pods) and [pod_manifests](https://github.com/deic-dk/pod_manifests)