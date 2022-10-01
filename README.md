# EKS Karpenter demo

Environment setup and test scenarios for scaling the EKS cluster with Karpenter

## Test environment set up

[0. Set up Cloud9 environment](0-envsetup/README.md)

[1. Launch EKS cluster](1-ekssetup/README.md)

[2. Deploy kube-ops-view](2-kube-ops-view/README.md)

[3. Install Karpenter](3-karpenter/README.md)

[4. Set up provisioner](4-provisioners/README.md)

## Testing

### 10 vCPU workloads

```
kubectl apply -f test-workloads/kr-10pods-100cpu.yaml

kubectl scale --replicas=5 deployment/inflate 

kubectl delete deployment inflate
```

### Random workloads
Generate random workloads - 2000 pods in total, batches of 500 pods, into namespace **"load"**:
```bash
#create the namespace for load testing
kubectl create namespace load 

cd generate-random-load
./create-workload.sh 2000 500 load
```

Delete random workloads:
```
cd generate-random-load
./delete-workload.sh load
```

### Consolidation testing
First install the [Provisioner with enabled Consolidation](4-provisioners/README.md#with-consolidation) and then:
```bash
./create-workload.sh 999 333 load

./delete-workload.sh load
```

### Test pods spread
With the [Default provisioner](4-provisioners/README.md#default-with-spot-instances) do:

```
kubectl apply -f test-test-workloads/kr-spread-400pods-100cpu.yaml

kubectl delete deployment inflate
```


