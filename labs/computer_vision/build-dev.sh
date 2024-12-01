#!/bin/bash
repo="saitcho"
image="labs-cv"
tag=0.1.8

docker build -t $repo/$image:$tag .
docker push $repo/$image:$tag
