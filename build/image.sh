#!/bin/bash -e

image_name="${1:-tgbyte/apacheds}"
dockerfile="${2:-Dockerfile}"
case ${CI_BUILD_REF_NAME} in
master)
  image_tag="latest"
  ;;
*)
  image_tag=${CI_BUILD_REF_NAME//[^0-9A-Za-z_.\-]/-}
  ;;
esac

docker build -t ${image_name}:${image_tag} -f "${dockerfile}" --no-cache --pull .
docker push ${image_name}:${image_tag}
