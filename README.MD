# Setup

## Network layout
```
Network: 192.168.1.0/24
Gateway: 192.168.1.1

DNS: 192.168.1.1 (running dnsmasq on DD-WRT Router)

Router DHCP range: 192.168.1.101 - 192.168.1.200
Reserved: 192.168.1.2 - 192.168.1.15

* 192.168.1.1 - Router
* 192.168.1.3 - Managed Switch
* 192.168.1.4 - RPi3 (media server)

Kubernetes Nodes:
    - Master1: 192.168.1.50
    - Node1: 192.168.1.55
    - Node2: 192.168.1.56

MetalLB CIDR: 192.168.1.16/28
    - 192.168.1.17 - 192.168.1.30

Traefik Internal Ingress IP: 192.168.1.20
Traefik External Ingress IP: 192.168.1.21
```

# Installing kube
## The basic setup for all PIs:

```
# On the router
# Create static IPs for all the PIs

# On all the PIs

# Set hostname
sudo rasbpi-config

# Configure the static ip
sudo vi /etc/dhcpcd.conf
profile static_eth0
static ip_address=192.168.184.21/24
static routers=192.168.184.1

# Install docker
curl -sSL get.docker.com | sh && \
  sudo usermod pi -aG docker

# Disable swap
sudo dphys-swapfile swapoff && \
  sudo dphys-swapfile uninstall && \
  sudo update-rc.d dphys-swapfile remove

# Install kube packages
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - && \
  echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list && \
  sudo apt-get update -q && \
  sudo apt-get install -qy kubeadm

# Enable cgroups in kernel
echo Adding " cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" to /boot/cmdline.txt

sudo cp /boot/cmdline.txt /boot/cmdline_backup.txt
orig="$(head -n1 /boot/cmdline.txt) cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory"

echo $orig | sudo tee /boot/cmdline.txt

# Reboot
sudo reboot
```

## Kubernetes on the master
```
# Setup kubernetes control pane
kubeadm init --token-ttl=0 --pod-network-cidr=10.244.0.0/16

# Patch startup time if this does not run becase of timeout
cd /etc/kubernetes/manifests/
vi kube-apiserver.yaml
kubeadm init --skip-phases=preflight,kubelet-start,certs,kubeconfig,control-plane,etcd

# Copy auth to non-root user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Network plugin (WeaveNet)
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
```

## Kubernetes on the node 
```
# Join the cluster using the token
kubeadm join 192.168.184.20:6443 --token xxx --discovery-token-ca-cert-hash sha256:xxx
```

# Installing plugins

## 1) Bare metal LoadBalancer: Metal
Installing metal:
```
kubectl create -f 1-metal/metal-configmap.yaml

kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.6.2/manifests/metallb.yaml
```

## 2) Traefik
```
# rbac
kubectl apply -f https://raw.githubusercontent.com/containous/traefik/master/examples/k8s/traefik-rbac.yaml

# Traefik using deployment
kubectl apply -f https://raw.githubusercontent.com/containous/traefik/master/examples/k8s/traefik-deployment.yaml

kubectl --n=kube-system get services # Get NodePort
curl <NODEIP>:<NODEPORT>
```

## 3) NFS Storage
I used one of the PIs as a remote NFS server.

### Server setup
```
sudo apt-get install nfs-kernel-server nfs-common
sudo systemctl enable nfs-kernel-server

# Create path for exports
sudo mkdir /pvs/

# Add following like to /etc/exports
/pvs/ 192.168.184.1/255.255.0.0(rw,sync,no_subtree_check,no_root_squash)

sudo exportfs -a
```

### Setup NFS auto provisioning on kubernetes
```
kubectl apply -f 3-nfs/nfs-provisioner-rbac.yaml
kubectl apply -f 3-nfs/nfs-provisioner.yaml
kubectl apply -f 3-nfs/nfs-storageclass.yaml

kubectl get storageclass
# If it's not the default storage class, change it

kubectl patch storageclass nfs-node1-sdcard -p '{"metadata":{"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'
```

## 4) Kubernetes dashboard
```
kubectl apply -f 4-dashboard/dashboard-rbac.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/alternative/kubernetes-dashboard-arm.yaml
```

## 5) Monitoring (Prometheus & Grafana)
```

```


