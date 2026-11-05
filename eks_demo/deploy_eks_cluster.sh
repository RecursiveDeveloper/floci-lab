#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"

if [[ ! -f "credential_setup.sh" ]]; then
  echo -e "\ncredential_setup.sh not found. Please create one...\n"
fi

IAM_USER="eks-admin"
CLUSTER_NAME="dev-cluster"
CLUSTER_ARN_ROLE="arn:aws:iam::000000000000:role/eks-role"

source credential_setup.sh

if aws iam list-users | grep -q "${IAM_USER}"; then
  echo -e "\nUser ${IAM_USER} already exists...\n"
else
  echo -e "\nCreating user ${IAM_USER}...\n"
  aws iam create-user --user-name "${IAM_USER}"
fi

for key in $(aws iam list-access-keys --user-name "${IAM_USER}" --query 'AccessKeyMetadata[].AccessKeyId' --output text); do
  aws iam delete-access-key --user-name "${IAM_USER}" --access-key-id "${key}"
done

read AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY <<< "$(aws iam create-access-key \
  --user-name "${IAM_USER}" --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text)"
  
sed -i "s|export AWS_ACCESS_KEY_ID=.*|export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}|" credential_setup.sh
sed -i "s|export AWS_SECRET_ACCESS_KEY=.*|export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}|" credential_setup.sh

source credential_setup.sh

if aws eks describe-cluster --name ${CLUSTER_NAME} >/dev/null 2>&1; then
  echo -e "\nCluster ${CLUSTER_NAME} already exists...\n"
else
  echo -e "\nCreating EKS cluster ${CLUSTER_NAME}...\n"
  aws eks create-cluster \
    --name ${CLUSTER_NAME} \
    --role-arn ${CLUSTER_ARN_ROLE} \
    --resources-vpc-config subnetIds=subnet-default-us-east-1-a 2>&1 | grep -v "ResourceInUseException" || true
  aws eks wait cluster-active --name ${CLUSTER_NAME}
fi

echo -e "\nUpdating eks cluster context...\n"
aws eks update-kubeconfig --name dev-cluster

kubectl get all --all-namespaces