build:
	@sudo bash setup.sh

remove:
	@docker-compose down --remove-orphans -v

stop:
	@docker-compose stop

start:
	@docker-compose start
	
mongo-user:
	@sudo bash scripts/mongo-user

notebook-bash:
	@docker exec -u 0 -it apache-zeppelin bash -c "passwd -d zeppelin"
	@echo "This Notebook sudo didn't have password"
	@docker exec -it apache-zeppelin bash