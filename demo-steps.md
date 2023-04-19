# KubeCon Demo Steps

This document details all the steps for the demo setup.

## 1. Create Temp Directory for Demo

All the resources we will use would be placed in a temporary directory.

```sh
{
    # Create a temp directory - some commands require files rather than piping
    # stdout, etc. This also makes it clear which file is being created / used.
    mkdir /tmp/kubecon-mco-demo/
    cd /tmp/kubecon-mco-demo/
}
```

## Extra 1. Create KinD Clusters

This demo utilises local KinD clusters. You can use other cluster setup as you
like.

```sh
{
    # Pull in KinD configurations for creating clusters from this GitHub repo,
    # with -O flag to write it out to a file with the same name. The KinD
    # clusters can be created without any specific configurations, but this step
    # makes sure you will be using the same version of Kubernetes, and also you
    # will get 2 nodes per cluster.
    #
    # There are some other network configurations in place, which are pretty
    # straightforward.
    curl -OsSL "https://github.com/rytswd/kubecon-eu-2023/raw/main/tools/kind-config/cluster-1-v1.26.yaml"
    curl -OsSL "https://github.com/rytswd/kubecon-eu-2023/raw/main/tools/kind-config/cluster-2-v1.26.yaml"
    curl -OsSL "https://github.com/rytswd/kubecon-eu-2023/raw/main/tools/kind-config/cluster-3-v1.26.yaml"

    # Start up KinD clusters using the above configurations. When creating the
    # clusters, make sure to name them differently so that we can easily target
    # the right cluster later.
    kind create cluster \
        --name cluster-1 \
        --config cluster-1-v1.26.yaml
    kind create cluster \
        --name cluster-2 \
        --config cluster-2-v1.26.yaml
    kind create cluster \
        --name cluster-3 \
        --config cluster-3-v1.26.yaml

    kind export kubeconfig --name cluster-1 --kubeconfig /tmp/kubecon-mco-demo/cluster-1-kubeconfig.yaml --internal
    kind export kubeconfig --name cluster-2 --kubeconfig /tmp/kubecon-mco-demo/cluster-2-kubeconfig.yaml --internal
    kind export kubeconfig --name cluster-3 --kubeconfig /tmp/kubecon-mco-demo/cluster-3-kubeconfig.yaml --internal
}
```

## 2. Prepare CA Certificates for mTLS

> **NOTE**: You should complete this step before installing Istio to clusters.

Multi-Cluster configuration needs mTLS. Rather than using some default dummy
certificate provided by Istio, let's make sure that we create a new certificate
for mTLS.

```sh
{
    # Pull in certificate creation Makefile setup from Istio. This setup uses
    # GitHub's archive link.
    curl -sSL https://codeload.github.com/istio/istio/tar.gz/1.17.2 | \
        tar -xz --strip=2 istio-1.17.2/tools/certs

    # Create Root CA certificate, which would then be used to sign Intermediate
    # CAs.
    make -f ./certs/Makefile.selfsigned.mk root-ca

    # Create Intermediate CA Certificates for each cluster. All clusters have
    # their own certs for security reason. These certs are signed by the above
    # Root CA.
    make -f ./certs/Makefile.selfsigned.mk cluster-1-cacerts
    make -f ./certs/Makefile.selfsigned.mk cluster-2-cacerts
    make -f ./certs/Makefile.selfsigned.mk cluster-3-cacerts


    # Create istio-system namespace, which would be used for Istio installation.
    # As secrets need to be created in the Istio's namespace, this is preparing
    # the namespace before Istio installation.
    kubectl create namespace --context kind-cluster-1 istio-system
    kubectl create namespace --context kind-cluster-2 istio-system
    kubectl create namespace --context kind-cluster-3 istio-system

    # Create a secret `cacerts`, which is used by Istio.
    # Istio's component `istiod` will use this, and if there is no secret in
    # place before `istiod` starts up, it would fall back to use Istio's
    # default CA which is only menat to be used for testing.
    kubectl create secret --context kind-cluster-1 \
        generic cacerts -n istio-system \
        --from-file=./cluster-1/ca-cert.pem \
        --from-file=./cluster-1/ca-key.pem \
        --from-file=./cluster-1/root-cert.pem \
        --from-file=./cluster-1/cert-chain.pem
    kubectl create secret --context kind-cluster-2 \
        generic cacerts -n istio-system \
        --from-file=./cluster-2/ca-cert.pem \
        --from-file=./cluster-2/ca-key.pem \
        --from-file=./cluster-2/root-cert.pem \
        --from-file=./cluster-2/cert-chain.pem
    kubectl create secret --context kind-cluster-3 \
        generic cacerts -n istio-system \
        --from-file=./cluster-3/ca-cert.pem \
        --from-file=./cluster-3/ca-key.pem \
        --from-file=./cluster-3/root-cert.pem \
        --from-file=./cluster-3/cert-chain.pem
}
```

## 2. Install Istio with Helm

```sh
{
    # Install Istio's "base" Helm Chart first.
    helm install \
        --kube-context kind-cluster-1 \
        -n istio-system \
        --repo https://istio-release.storage.googleapis.com/charts \
        istio-base \
        base
    helm install \
        --kube-context kind-cluster-2 \
        -n istio-system \
        --repo https://istio-release.storage.googleapis.com/charts \
        istio-base \
        base
    helm install \
        --kube-context kind-cluster-3 \
        -n istio-system \
        --repo https://istio-release.storage.googleapis.com/charts \
        istio-base \
        base

    # Install istiod, Istio's Control Plane.
    helm install \
        --kube-context kind-cluster-1 \
        -n istio-system \
        --repo https://istio-release.storage.googleapis.com/charts \
        istiod \
        istiod
    helm install \
        --kube-context kind-cluster-2 \
        -n istio-system \
        --repo https://istio-release.storage.googleapis.com/charts \
        istiod \
        istiod
    helm install \
        --kube-context kind-cluster-3 \
        -n istio-system \
        --repo https://istio-release.storage.googleapis.com/charts \
        istiod \
        istiod
}
```

## Clean Up

Simply delete all the clusters.

```sh
{
    kind delete cluster --name cluster-1
    kind delete cluster --name cluster-2
    kind delete cluster --name cluster-3
}
```
