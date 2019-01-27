# Kubernetes with a few addons on a raspberry PI cluster
Inspired by:
- https://www.hanselman.com/blog/HowToBuildAKubernetesClusterWithARMRaspberryPiThenRunNETCoreOnOpenFaas.aspx
- https://itnext.io/building-an-arm-kubernetes-cluster-ef31032636f9
- https://blog.alexellis.io/serverless-kubernetes-on-raspberry-pi/

Sources copied/modified from: 
- https://github.com/carlosedp/kubernetes-arm
- https://github.com/carlosedp/prometheus-operator-ARM
- https://github.com/carlosedp/prometheus-ARM

# Setup
![cluster](https://github.com/retocode/raspberry-k8s/raw/master/img/raspi_cluster.jpg "The raspberry pi cluster")

## Parts
- 5x Raspberry PI B+
- 5x Samsung Evo+ 32GB, Class 10 microSD
- Anker PowerPort 6 (12A, 60W)
- Renkforce 8-Port Switch (USB powered)
- Ethernet and Micro-USB-Cables
- 5 Layer Raspberry PI Stack Case

## Network layout
```
Network: 192.168.184.0/24
Gateway: 192.168.184.1

DNS: 192.168.184.1

* 192.168.184.1 - Router
* 192.168.184.100-249 DHCP Range

Kubernetes Nodes:
    - k8s-master1: 192.168.184.20
    - k8s-node1: 192.168.184.21 (also NFS server)
    - k8s-node2: 192.168.184.22
    - k8s-node3: 192.168.184.23
    - k8s-node4: 192.168.184.24

MetalLB CIDR: 192.168.184.49/28
    - 192.168.184.48 - 192.168.184.62

Traefik Internal Ingress IP: 192.168.184.48
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
static ip_address=192.168.184.xx/24
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

## 1) Load balancers with metal
Installing metal:
```
kubectl apply -f 1-metal
```

## 2) Traefik
```
# rbac
kubectl apply -f 2-traefik

# Get external IP from metal LB
kubectl -n=kube-system get services
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
kubectl apply -f 4-dashboard
```

## 5) Monitoring (Prometheus & Grafana)
```
# Build docker images
5-monitoring/build_images.sh

# Expose necessary services on all masters & workers
5-monitoring/expose_services.sh

# Create services with open ports
kubectl apply -f 5-monitoring/k8s

# Deploy prometheus operator
export NAMESPACE='monitoring'
kubectl create namespace "$NAMESPACE"
kubectl --namespace="$NAMESPACE" apply -f 5-monitoring/prometheus-operator

# Wait for deployment of CRDs
until kubectl --namespace="$NAMESPACE" get alertmanagers.monitoring.coreos.com > /dev/null 2>&1; do sleep 1; printf "."; done

# Deploy exporters
kubectl --namespace="$NAMESPACE" apply -f 5-monitoring/node-exporter
kubectl --namespace="$NAMESPACE" apply -f 5-monitoring/arm-exporter

# Kube state metrics
kubectl --namespace="$NAMESPACE" apply -f 5-monitoring/kube-state-metrics
kubectl --namespace="$NAMESPACE" apply -f 5-monitoring/grafana

# Prometheus
find 5-monitoring/prometheus -type f ! -name prometheus-k8s-roles.yaml ! -name prometheus-k8s-role-bindings.yaml -exec kubectl --namespace "$NAMESPACE" apply -f {} \;

kubectl apply -f 5-monitoring/prometheus/prometheus-k8s-roles.yaml
kubectl apply -f 5-monitoring/prometheus/prometheus-k8s-role-bindings.yaml

# Alertmanager
kubectl --namespace="$NAMESPACE" apply -f 5-monitoring/alertmanager

```

