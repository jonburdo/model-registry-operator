#!/bin/bash
set -e

MR_TOKEN=$(oc whoami -t)
MR_BASE_URL="https://$(oc get route -n odh-model-registries mr1-https -o 'jsonpath={.status.ingress[0].host}')"

MODEL_ID=$(curl -sk -H"Authorization: Bearer $MR_TOKEN" "$MR_BASE_URL/api/model_registry/v1alpha3/registered_models" | jq -r '.items | max_by(.lastUpdateTimeSinceEpoch | tonumber) | .id')
MODEL_VERSION_ID=$(curl -sk -H"Authorization: Bearer $MR_TOKEN" "$MR_BASE_URL/api/model_registry/v1alpha3/registered_models/"$MODEL_ID"/versions" | jq -r '.items | max_by(.lastUpdateTimeSinceEpoch | tonumber) | .id')
MODEL_ARTIFACT_ID=$(curl -sk -H"Authorization: Bearer $MR_TOKEN" "$MR_BASE_URL/api/model_registry/v1alpha3/model_versions/$MODEL_VERSION_ID/artifacts" | jq -r '.items | max_by(.lastUpdateTimeSinceEpoch | tonumber) | .id')

oc process --local -f jobs-async-upload-uri-to-oci-template.yaml \
  -p MODEL_SYNC_MODEL_ID="$MODEL_ID" \
  -p MODEL_SYNC_MODEL_VERSION_ID="$MODEL_VERSION_ID" \
  -p MODEL_SYNC_MODEL_ARTIFACT_ID="$MODEL_ARTIFACT_ID" \
  -p MODEL_SYNC_REGISTRY_SERVER_ADDRESS="$MR_BASE_URL" \
  -p MODEL_SYNC_REGISTRY_PORT="443" \
  -p MODEL_SYNC_SOURCE_URI="https://huggingface.co/tarilabs/mnist/resolve/v1.nb20231206162408/mnist.onnx" \
  -p MODEL_SYNC_DESTINATION_OCI_URI="default-route-openshift-image-registry.apps.rosa.jburdo-cluster.d4bs.p3.openshiftapps.com/minio-manual/model2:latest" \
  -p MODEL_SYNC_DESTINATION_OCI_REGISTRY="default-route-openshift-image-registry.apps.rosa.jburdo-cluster.d4bs.p3.openshiftapps.com" \
  -o yaml > job.yaml
