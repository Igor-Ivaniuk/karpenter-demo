#!/bin/bash

export NAMESPACE=${1:-default}

set -eo pipefail

kubectl get deploy -n $NAMESPACE \
	| grep batch \
	| awk '{print $1}' \
	| xargs kubectl delete deploy -n $NAMESPACE