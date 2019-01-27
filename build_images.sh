#!/bin/bash

# Prerequesites
# go installed & path set to $HOME/go
# manifest tool in path: https://github.com/estesp/manifest-tool/releases
REPO=retocode

AOM_VERSION=2.1
KSM_VERSION=v1.5.0
PROMOPERATOR_VERSION=v0.27.0
PROM_VERSION=v2.6.1
CONFIGMAP_VERSION=v0.2.2
NODEEXP_VERSION=v0.17.0
ALERTM_VERSION=v0.15.3

# Kubernetes addon-resizer
# Retag Addon-resizer google images to have unified manifest on DockerHub
docker pull gcr.io/google-containers/addon-resizer-arm64:$AOM_VERSION
docker pull gcr.io/google-containers/addon-resizer-arm:$AOM_VERSION

docker tag gcr.io/google-containers/addon-resizer-arm64:$AOM_VERSION $REPO/addon-resizer:$AOM_VERSION-arm64
docker tag gcr.io/google-containers/addon-resizer-arm:$AOM_VERSION $REPO/addon-resizer:$AOM_VERSION-arm

docker push $REPO/addon-resizer:$AOM_VERSION-arm
docker push $REPO/addon-resizer:$AOM_VERSION-arm64

manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/addon-resizer:$AOM_VERSION-ARCH --target $REPO/addon-resizer:$AOM_VERSION
manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/addon-resizer:$AOM_VERSION-ARCH --target $REPO/addon-resizer:latest

# Retag carlosedp/arm_exporter to have unified manifest on DockerHub
docker pull carlosedp/arm_exporter:arm
docker pull carlosedp/arm_exporter:arm64

docker tag carlosedp/arm_exporter:arm $REPO/arm_exporter:v1.0.0-arm
docker tag carlosedp/arm_exporter:arm64 $REPO/arm_exporter:v1.0.0-arm64

docker push $REPO/arm_exporter:v1.0.0-arm
docker push $REPO/arm_exporter:v1.0.0-arm64

manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/arm_exporter:v1.0.0-ARCH --target $REPO/arm_exporter:v1.0.0
manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/arm_exporter:v1.0.0-ARCH --target $REPO/arm_exporter:latest

# Kube-state-metrics
go get github.com/kubernetes/kube-state-metrics
mv $HOME/go/src/github.com/kubernetes/kube-state-metrics $HOME/go/src/k8s.io/kube-state-metrics
cd $HOME/go/src/k8s.io/kube-state-metrics
git checkout ${KSM_VERSION}
GOOS=linux GOARCH=arm go build .
docker build -t $REPO/kube-state-metrics:${KSM_VERSION}-arm .

GOOS=linux GOARCH=arm64 go build .
docker build -t $REPO/kube-state-metrics:${KSM_VERSION}-arm64 .

docker push $REPO/kube-state-metrics:$KSM_VERSION-arm
docker push $REPO/kube-state-metrics:$KSM_VERSION-arm64

manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/kube-state-metrics:$KSM_VERSION-ARCH --target $REPO/kube-state-metrics:$KSM_VERSION
manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/kube-state-metrics:$KSM_VERSION-ARCH --target $REPO/kube-state-metrics:latest

# Prometheus-operator
go get github.com/coreos/prometheus-operator
cd $HOME/go/src/github.com/coreos/prometheus-operator
git checkout ${PROMOPERATOR_VERSION}

go get -u github.com/prometheus/promu

cat Dockerfile |sed -e 's/\.build\/linux-amd64\/operator/operator/' |sed -e 's/^FROM.*/FROM busybox/' > Dockerfile.arm

GOOS=linux GOARCH=arm $GOPATH/bin/promu build --prefix `pwd`
docker build -t $REPO/prometheus-operator:${PROMOPERATOR_VERSION}-arm -f Dockerfile.arm .

GOOS=linux GOARCH=arm64 $GOPATH/bin/promu build --prefix `pwd`
docker build -t $REPO/prometheus-operator:${PROMOPERATOR_VERSION}-arm64 -f Dockerfile.arm .

docker push $REPO/prometheus-operator:$PROMOPERATOR_VERSION-arm
docker push $REPO/prometheus-operator:$PROMOPERATOR_VERSION-arm64

manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/prometheus-operator:$PROMOPERATOR_VERSION-ARCH --target $REPO/prometheus-operator:$PROMOPERATOR_VERSION
manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/prometheus-operator:$PROMOPERATOR_VERSION-ARCH --target $REPO/prometheus-operator:latest

rm Dockerfile.arm

# prometheus-config-reloader
go get github.com/coreos/prometheus-operator
cd $HOME/go/src/github.com/coreos/prometheus-operator/
git checkout ${PROMOPERATOR_VERSION}
cd $HOME/go/src/github.com/coreos/prometheus-operator/cmd/prometheus-config-reloader

cat Dockerfile |sed -e 's/^FROM.*/FROM busybox/' > Dockerfile.arm

GOOS=linux GOARCH=arm CGO_ENABLED=0 go build -o prometheus-config-reloader main.go
docker build -t $REPO/prometheus-config-reloader:${PROMOPERATOR_VERSION}-arm -f Dockerfile.arm .

GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o prometheus-config-reloader main.go
docker build -t $REPO/prometheus-config-reloader:${PROMOPERATOR_VERSION}-arm64 -f Dockerfile.arm .

docker push $REPO/prometheus-config-reloader:$PROMOPERATOR_VERSION-arm
docker push $REPO/prometheus-config-reloader:$PROMOPERATOR_VERSION-arm64

manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/prometheus-config-reloader:$PROMOPERATOR_VERSION-ARCH --target $REPO/prometheus-config-reloader:$PROMOPERATOR_VERSION
manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/prometheus-config-reloader:$PROMOPERATOR_VERSION-ARCH --target $REPO/prometheus-config-reloader:latest

rm Dockerfile.arm

# configmap-reload
go get gopkg.in/fsnotify.v1
go get github.com/jimmidyson/configmap-reload  
cd $HOME/go/src/github.com/jimmidyson/configmap-reload
git checkout ${CONFIGMAP_VERSION}

cat Dockerfile |sed -e 's/^FROM.*/FROM busybox/' | sed -e 's/^COPY.*/COPY configmap-reload \/configmap-reload/' > Dockerfile.arm

GOOS=linux GOARCH=arm CGO_ENABLED=0 go build -o configmap-reload configmap-reload.go
docker build -t $REPO/configmap-reload:${CONFIGMAP_VERSION}-arm -f Dockerfile.arm .

GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o configmap-reload configmap-reload.go
docker build -t $REPO/configmap-reload:${CONFIGMAP_VERSION}-arm64 -f Dockerfile.arm .

docker push $REPO/configmap-reload:$CONFIGMAP_VERSION-arm
docker push $REPO/configmap-reload:$CONFIGMAP_VERSION-arm64

manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/configmap-reload:$CONFIGMAP_VERSION-ARCH --target $REPO/configmap-reload:$CONFIGMAP_VERSION
manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/configmap-reload:$CONFIGMAP_VERSION-ARCH --target $REPO/configmap-reload:latest

rm Dockerfile.arm

# prometheus node_exporter
go get github.com/prometheus/node_exporter
cd $HOME/go/src/github.com/prometheus/node_exporter
git checkout ${NODEEXP_VERSION}

GOOS=linux GOARCH=arm CGO_ENABLED=0 go build -o node_exporter node_exporter.go 
docker build -t $REPO/node_exporter:${NODEEXP_VERSION}-arm -f Dockerfile.arm .

GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o node_exporter node_exporter.go
docker build -t $REPO/node_exporter:${NODEEXP_VERSION}-arm64 -f Dockerfile.arm .

docker push $REPO/node_exporter:$NODEEXP_VERSION-arm
docker push $REPO/node_exporter:$NODEEXP_VERSION-arm64

manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/node_exporter:$NODEEXP_VERSION-ARCH --target $REPO/node_exporter:$NODEEXP_VERSION
manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/node_exporter:$NODEEXP_VERSION-ARCH --target $REPO/node_exporter:latest

# prometheus
go get github.com/kevinjqiu/pat
go get github.com/prometheus/prometheus
cd $HOME/go/src/github.com/prometheus/prometheus  
git checkout $PROM_VERSION

GOOS=linux GOARCH=arm CGO_ENABLED=0 GO111MODULE=on /Users/reto/go/bin/promu build --prefix /Users/reto/go/src/github.com/prometheus/prometheus
docker build -t $REPO/prometheus:${PROM_VERSION}-arm .

GOOS=linux GOARCH=arm64 CGO_ENABLED=0 GO111MODULE=on /Users/reto/go/bin/promu build --prefix /Users/reto/go/src/github.com/prometheus/prometheus
docker build -t $REPO/prometheus:${PROM_VERSION}-arm64 .

docker push $REPO/prometheus:$PROM_VERSION-arm
docker push $REPO/prometheus:$PROM_VERSION-arm64

manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/prometheus:$PROM_VERSION-ARCH --target $REPO/prometheus:$PROM_VERSION
manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/prometheus:$PROM_VERSION-ARCH --target $REPO/prometheus:latest

# alert manager
go get github.com/prometheus/alertmanager
cd $HOME/go/src/github.com/prometheus/alertmanager
git checkout $ALERTM_VERSION

GOOS=linux GOARCH=arm CGO_ENABLED=0 /Users/reto/go/bin/promu build --prefix /Users/reto/go/src/github.com/prometheus/alertmanager
docker build -t $REPO/alertmanager:${ALERTM_VERSION}-arm .

GOOS=linux GOARCH=arm64 CGO_ENABLED=0 /Users/reto/go/bin/promu build --prefix /Users/reto/go/src/github.com/prometheus/alertmanager
docker build -t $REPO/alertmanager:${ALERTM_VERSION}-arm64 .

docker push $REPO/alertmanager:$ALERTM_VERSION-arm
docker push $REPO/alertmanager:$ALERTM_VERSION-arm64

manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/alertmanager:$ALERTM_VERSION-ARCH --target $REPO/alertmanager:$ALERTM_VERSION
manifest-tool-darwin-amd64 --username=retocode --password=$PASS push from-args --platforms linux/arm,linux/arm64 --template $REPO/alertmanager:$ALERTM_VERSION-ARCH --target $REPO/alertmanager:latest

