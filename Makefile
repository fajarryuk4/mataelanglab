build:
	@sudo bash setup.sh

remove:
	@sudo docker-compose down --remove-orphans -v && sudo rm -rf ./volume/mongochart

stop:
	@sudo bash scripts/stop.sh

start:
	@sudo bash scripts/start.sh
	
mongo-user:
	@sudo bash scripts/mongo-user.sh

help:
	@cat scripts/make-info.txt

info:
	@cat scripts/web-info.txt

modul-list:
	@sudo docker-compose ps -a

reset-notebook:
	@sudo bash scripts/reset-notebook.sh

