#!bin/bash

file=`cat mode`

sudo docker-compose --file $file stop