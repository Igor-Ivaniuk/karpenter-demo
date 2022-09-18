# Create EKS cluster with Karpenter

## 1. Define environment variables
```
export KARPENTER_VERSION=v0.16.0

export CLUSTER_NAME="eks-karpenter-demo"
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

# check that we correctly configure our vars
echo $KARPENTER_VERSION $CLUSTER_NAME $AWS_REGION $AWS_ACCOUNT_ID
```

## 2. Launch EKS cluster
```
eksctl create cluster -f - << EOF
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: ${CLUSTER_NAME}
  region: ${AWS_REGION}
  version: "1.23"
  tags:
    karpenter.sh/discovery: ${CLUSTER_NAME}
managedNodeGroups:
  - instanceType: c5.2xlarge
    amiFamily: AmazonLinux2
    name: ${CLUSTER_NAME}-ng
    desiredCapacity: 1
    minSize: 1
    maxSize: 2
iam:
  withOIDC: true
EOF

export CLUSTER_ENDPOINT="$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.endpoint" --output text)"
echo "export CLUSTER_ENDPOINT=${CLUSTER_ENDPOINT}" | tee -a ~/.bash_profile
```

## 3. (Optional) Add your IAM user to the Kubernetes configmap
If no cluster resources are visible in your EKS cluster in the AWS console, you may want to allow your current IAM user or console role to be authorized in EKS, to display cluster details. 
This guide assumes that you already have an IAM user or role that has access to EKS cluster. The following example policy includes the necessary permissions for a user or role to view Kubernetes resources for all clusters in your account. Replace 111122223333 with your account ID.
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:ListFargateProfiles",
                "eks:DescribeNodegroup",
                "eks:ListNodegroups",
                "eks:ListUpdates",
                "eks:AccessKubernetesApi",
                "eks:ListAddons",
                "eks:DescribeCluster",
                "eks:DescribeAddonVersions",
                "eks:ListClusters",
                "eks:ListIdentityProviderConfigs",
                "iam:ListRoles"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "ssm:GetParameter",
            "Resource": "arn:aws:ssm:*:111122223333:parameter/*"
        }
    ]
}  
```

Now we will add the identity mapping into the EKS cluster. We will use a separate user group in the Kubernetes RBAC.

Create a Kubernetes group to view resources in all namespaces. The group name in the file is ```eks-console-dashboard-full-access-group```. Apply the manifest to your cluster with the following command:
```
kubectl apply -f https://s3.us-west-2.amazonaws.com/amazon-eks/docs/eks-console-full-access.yaml
```

Check the existing identity mappings
```
eksctl get iamidentitymapping --cluster ${CLUSTER_NAME} --region=${AWS_REGION}
```

**Option 1.** Add mapping to the IAM user:
```
eksctl create iamidentitymapping \
    --cluster ${CLUSTER_NAME} \
    --region=${AWS_REGION} \
    --arn arn:aws:iam::111122223333:user/my-user \
    --group eks-console-dashboard-full-access-group \
    --no-duplicate-arns
```

**Option 2.** Add mapping to the IAM role:
```
eksctl create iamidentitymapping \
    --cluster ${CLUSTER_NAME} \
    --region=${AWS_REGION} \
    --arn arn:aws:iam::111122223333:role/my-console-viewer-role \
    --group eks-console-dashboard-full-access-group \
    --no-duplicate-arns
```

View the mappings in the ConfigMap again
```
eksctl get iamidentitymapping --cluster ${CLUSTER_NAME} --region=${AWS_REGION}
```