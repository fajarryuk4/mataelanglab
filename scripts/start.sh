#!bin/bash

file=`cat /etc/mataelanglab/mode`

sudo docker-compose --file $file start

cat scripts/web-info.txt