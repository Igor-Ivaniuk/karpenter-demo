# Set up Karpenter

## Create the KarpenterNode IAM Role
Instances launched by Karpenter must run with an **InstanceProfile** that grants permissions necessary to run containers and configure networking. Karpenter discovers the InstanceProfile using the name ```KarpenterNodeRole-${ClusterName}```.

Store the env variables
```
export KARPENTER_VERSION=v0.16.1
echo "export KARPENTER_VERSION=${KARPENTER_VERSION}" | tee -a ~/.bash_profile
```

First, create the IAM resources using AWS CloudFormation.
```
TEMPOUT=$(mktemp)

curl -fsSL https://karpenter.sh/"${KARPENTER_VERSION}"/getting-started/getting-started-with-eksctl/cloudformation.yaml  > $TEMPOUT \
&& aws cloudformation deploy \
  --stack-name "Karpenter-${CLUSTER_NAME}" \
  --template-file "${TEMPOUT}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides "ClusterName=${CLUSTER_NAME}"
```

Second, grant access to instances using the profile to connect to the cluster. This command adds the Karpenter node role to your aws-auth configmap, allowing nodes with this role to connect to the cluster.
```
eksctl create iamidentitymapping \
  --username system:node:{{EC2PrivateDNSName}} \
  --cluster  ${CLUSTER_NAME} \
  --arn "arn:aws:iam::${ACCOUNT_ID}:role/KarpenterNodeRole-${CLUSTER_NAME}" \
  --group system:bootstrappers \
  --group system:nodes
```

Verify the entry is now in the AWS auth map by running the following command.
```
kubectl describe configmap -n kube-system aws-auth
```

## Create KarpenterController IAM Role
Before adding the IAM Role for the service account we need to create the IAM OIDC Identity Provider for the cluster.
```
eksctl utils associate-iam-oidc-provider --cluster ${CLUSTER_NAME} --approve
```

Karpenter requires permissions like launching instances. This will create an AWS IAM Role, Kubernetes service account, and associate them using IAM Roles for Service Accounts (IRSA)
```
eksctl create iamserviceaccount \
  --cluster "${CLUSTER_NAME}" --name karpenter --namespace karpenter \
  --role-name "${CLUSTER_NAME}-karpenter" \
  --attach-policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/KarpenterControllerPolicy-${CLUSTER_NAME}" \
  --role-only \
  --approve

export KARPENTER_IAM_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${CLUSTER_NAME}-karpenter"
echo "export KARPENTER_IAM_ROLE_ARN=${KARPENTER_IAM_ROLE_ARN}" | tee -a ~/.bash_profile
```

## Create the EC2 Spot Linked Role
Finally, we will create the spot EC2 Spot Linked role.
This step is only necessary if this is the first time you’re using EC2 Spot in this account. If the role has already been successfully created, you will see: *An error occurred (InvalidInput) when calling the CreateServiceLinkedRole operation: Service role name AWSServiceRoleForEC2Spot has been taken in this account, please try a different suffix.* Just ignore the error and proceed with the next steps.
```
aws iam create-service-linked-role --aws-service-name spot.amazonaws.com
```

## Install Helm if not yet installed
```
curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm repo add stable https://charts.helm.sh/stable
helm completion bash >> ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion
source <(helm completion bash)
```

## Install Karpenter Helm Chart
Before the chart can be installed the repo needs to be added to Helm, run the following commands to add the repo.
```
helm repo add karpenter https://charts.karpenter.sh/
helm repo update
```

Install the chart passing in the cluster details and the Karpenter role ARN.
```
helm upgrade --install --namespace karpenter --create-namespace \
  karpenter karpenter/karpenter \
  --version ${KARPENTER_VERSION} \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${KARPENTER_IAM_ROLE_ARN} \
  --set clusterName=${CLUSTER_NAME} \
  --set clusterEndpoint=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.endpoint" --output json) \
  --set defaultProvisioner.create=false \
  --set aws.defaultInstanceProfile=KarpenterNodeInstanceProfile-${CLUSTER_NAME} \
  --wait # for the defaulting webhook to install before creating a Provisioner
```

The command above:
* uses the CLUSTER_NAME so that Karpenter controller can contact the Cluster API Server.
* Karpenter configuration is provided through a Custom Resource Definition. We will be learning about providers in the next section, the --wait notifies the webhook controller to wait until the Provisioner CRD has been deployed.

To check Karpenter is running you can check the Pods, Deployment and Service are Running.
```
kubectl get all -n karpenter
```

To check the deployment. There should be one deployment karpenter
```
kubectl get deployment -n karpenter
```

To check running pods run the command below. There should be at least two pods, each having two containers controller and webhook

```
kubectl get pods --namespace karpenter
```

To check containers controller and webhook, describe pod using following command
```
kubectl get pod -n karpenter --no-headers | awk '{print $1}' | head -n 1 | xargs kubectl describe pod -n karpenter
```

