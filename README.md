# EKS Karpenter demo

Environment setup and test scenarios for scaling the EKS cluster with Karpenter

## Test environment set up

[0. Set up Cloud9 environment](0-envsetup/README.md)

[1. Launch EKS cluster](1-ekssetup/README.md)

[2. Deploy kube-ops-view](2-kube-ops-view/README.md)

[3. Install Karpenter](3-karpenter/README.md)

[4. Set up provisioner](4-provisioners/README.md)

## Testing

Generate random workloads - 2000 pods in total, batches of 500 pods, into namespace **"load"**:
```bash
./generate-random-load/create-workload.sh 2000 500 load
```

