#!bin/bash

docker exec -it -u 0 spark-notebook rm -rf 01-QuickstartNotebooks 02-IDSNotebooks output
docker exec -it -u 0 spark-notebook cp -rp -a /root/. ./


