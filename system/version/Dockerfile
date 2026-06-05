# Container image that runs the mcix command line tool
ARG CONTAINER_REGISTRY
ARG IMAGE_NAME
ARG IMAGE_TAG

FROM ${CONTAINER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}

# Copies the entrypoint file from the action repository to the filesystem path `/` of the container
COPY entrypoint.sh /entrypoint.sh

# File to execute when the docker container starts up
ENTRYPOINT ["/entrypoint.sh"]
