#!/bin/bash

export HOST="koob.home.bitnebula.com"
export PORT=2222
export RECIPE="boss"

./common.sh

ssh root@koob 'rm -rf /root/talos'
ssh root@koob 'scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null boss:/home/boss/talos /root/'
ssh root@koob 'scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null boss:/usr/local/bin/mkvmlab.sh /root/'
