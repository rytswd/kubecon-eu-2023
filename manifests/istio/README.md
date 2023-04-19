Istio installation specs are generated with the following commands:

```sh
{
    istioctl manifest generate \
        -f manifests/istio/istio-operator/iop-istiod-cluster-1.yaml \
        > manifests/istio/installation/istiod-manifests-cluster-1.yaml
    istioctl manifest generate \
        -f manifests/istio/istio-operator/iop-istiod-cluster-2.yaml \
        > manifests/istio/installation/istiod-manifests-cluster-2.yaml
    istioctl manifest generate \
        -f manifests/istio/istio-operator/iop-istiod-cluster-3.yaml \
        > manifests/istio/installation/istiod-manifests-cluster-3.yaml
}
```

``` sh
{
    istioctl manifest generate \
        -f manifests/istio/istio-operator/iop-istio-gateway-cluster-1.yaml \
        > manifests/istio/installation/istio-gateway-manifests-cluster-1.yaml
    istioctl manifest generate \
        -f manifests/istio/istio-operator/iop-istio-gateway-cluster-2.yaml \
        > manifests/istio/installation/istio-gateway-manifests-cluster-2.yaml
    istioctl manifest generate \
        -f manifests/istio/istio-operator/iop-istio-gateway-cluster-3.yaml \
        > manifests/istio/installation/istio-gateway-manifests-cluster-3.yaml
}
```
