#!bin/bash

file=`cat /etc/mataelanglab/mode`

sudo docker-compose --file $file stop