#!/bin/bash
repo="crjslabs.azurecr.io"
image="labs-cv"
tag=0.1

docker build -t $repo/$image:$tag .
docker push $repo/$image:$tag
