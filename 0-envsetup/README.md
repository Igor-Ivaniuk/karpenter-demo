# Prepare environment

## 1. Set up Cloud9 Environment

**A. Disable Cloud9 AWS temporary credentials**
Go to Cloud9
* Open the "Preferences" tab.
* Open the "AWS Settings" and disable "AWS Managed Temporary Credentials"

**B. Update installed packages and install eksctl**
```
sudo yum update -y

curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

sudo mv -v /tmp/eksctl /usr/local/bin

eksctl completion bash >> ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion
```
**C. Install kubectl**

```
sudo curl --silent --location -o /usr/local/bin/kubectl \
   https://s3.us-west-2.amazonaws.com/amazon-eks/1.21.5/2022-01-21/bin/linux/amd64/kubectl

sudo chmod +x /usr/local/bin/kubectl
```

**D. Install latest awscli**
```
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**E. Install jq, envsubst (from GNU gettext utilities) and bash-completion**
```
sudo yum -y install jq gettext bash-completion moreutils
```

**F. Install yq for yaml processing**
```
echo 'yq() {
  docker run --rm -i -v "${PWD}":/workdir mikefarah/yq "$@"
}' | tee -a ~/.bashrc && source ~/.bashrc
```

**G. Install c9 to open files in cloud9**
```
npm install -g c9
```
Below is one example:
```
c9 open ~/file.yaml
```

**H. Install k9s a Kubernetes CLI To Manage Your Clusters In Style!**
```
curl -sS https://webinstall.dev/k9s | bash
```

**I. Verify the binaries are in the path and executable**
```
for command in kubectl jq envsubst aws
  do
    which $command &>/dev/null && echo "$command in path" || echo "$command NOT FOUND"
  done
```

**J. Enable kubectl bash_completion**
```
kubectl completion bash >>  ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion
```

**K. Enable some kubernetes aliases**
```
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install --all
sudo curl https://raw.githubusercontent.com/blendle/kns/master/bin/kns -o /usr/local/bin/kns && sudo chmod +x $_
sudo curl https://raw.githubusercontent.com/blendle/kns/master/bin/ktx -o /usr/local/bin/ktx && sudo chmod +x $_
echo "alias kgn='kubectl get nodes -L beta.kubernetes.io/arch -L eks.amazonaws.com/capacityType -L beta.kubernetes.io/instance-type -L eks.amazonaws.com/nodegroup -L topology.kubernetes.io/zone -L karpenter.sh/provisioner-name -L karpenter.sh/capacity-type'" | tee -a ~/.bashrc
source ~/.bashrc
```

**L. Disable Cloud9 AWS temporary credentials To ensure temporary credentials aren’t already in place we will also remove any existing credentials file:**
```
aws cloud9 update-environment  --environment-id $C9_PID --managed-credentials-action DISABLE
rm -vf ${HOME}/.aws/credentials
```

**M. Export AWS region and Account ID to bash profile**
```
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
export AZS=($(aws ec2 describe-availability-zones --query 'AvailabilityZones[].ZoneName' --output text --region $AWS_REGION))
echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ~/.bash_profile
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
echo "export AZS=(${AZS[@]})" | tee -a ~/.bash_profile
aws configure set default.region ${AWS_REGION}
aws configure get default.region
```

## 2. Increase the disk size on the Cloud9 instance
The following command adds more disk space to the root volume of the EC2 instance that Cloud9 runs on. Once the command completes, it reboots the instance and it could take a minute or two for the IDE to come back online.
```
pip3 install --user --upgrade boto3
export instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
python -c "import boto3
import os
from botocore.exceptions import ClientError 
ec2 = boto3.client('ec2')
volume_info = ec2.describe_volumes(
    Filters=[
        {
            'Name': 'attachment.instance-id',
            'Values': [
                os.getenv('instance_id')
            ]
        }
    ]
)
volume_id = volume_info['Volumes'][0]['VolumeId']
try:
    resize = ec2.modify_volume(    
            VolumeId=volume_id,    
            Size=30
    )
    print(resize)
except ClientError as e:
    if e.response['Error']['Code'] == 'InvalidParameterValue':
        print('ERROR MESSAGE: {}'.format(e))"
if [ $? -eq 0 ]; then
    sudo reboot
fi
```

## 3. Confirm EKS Setup
You can test access to your cluster by running the following command. The output will be a list of worker nodes
```
kubectl get nodes
```
If no cluster is running, please create it according to [1-ekssetup/README.md](../1-ekssetup/README.md)