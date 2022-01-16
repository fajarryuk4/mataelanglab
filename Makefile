build:
	@sudo bash setup.sh

remove:
	@sudo docker-compose down --remove-orphans -v

stop:
	@sudo docker-compose stop

start:
	@sudo docker-compose start
	
mongo-user:
	@sudo bash scripts/mongo-user

notebook-bash:
	@sudo docker exec -u 0 -it apache-zeppelin bash -c "passwd -d zeppelin"
	@echo "This Notebook sudo didn't have password"
	@sudo docker exec -it apache-zeppelin bash

stanalone-rebuild:
	@sudo docker-compose up -d

spark-cluster-rebuild:
	@sudo docker-compose --file docker-compose-spark.yml up -d

hive-cluster-rebuild:
	@sudo docker-compose docker-compose-hive.yml up -d
