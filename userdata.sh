#!/bin/bash

apt update -y
apt install -y docker.io

systemctl enable docker
systemctl start docker

docker pull harikrishdocker25/test-app

docker run -d \
  --name test-app \
  --restart always \
  -p 5000:3000 \
  harikrishdocker25/test-app