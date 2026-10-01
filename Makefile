CURR_USER = tmoga
COMPOSE = docker compose -f srcs/docker-compose.yml

all: up

up:
	mkdir -p /home/$(CURR_USER)/data/db_data
	mkdir -p /home/$(CURR_USER)/data/wp_data
	$(COMPOSE) up --build -d

stop:
	$(COMPOSE) stop

down:
	$(COMPOSE) down

clean: down
	$(COMPOSE) down --rmi all

fclean: clean
	sudo rm -rf /home/$(CURR_USER)/data/db_data
	sudo rm -rf /home/$(CURR_USER)/data/wp_data

re: fclean all

.PHONY: all up stop down clean fclean re
