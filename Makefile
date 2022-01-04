build:
	@sudo bash setup.sh

remove:
	@docker-compose down --remove-orphans -v