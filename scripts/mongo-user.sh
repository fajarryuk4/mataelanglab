#!bin/bash

#run as root checker
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

echo -e "\nInput Mongo Chart UserAdmin Account"
read -p "Username: " USERNAME
read -s -p "Password: " PASSWORD

#Create Charts users
if [ "$( docker container inspect -f '{{.State.Running}}' mongo-charts )" == "true" ];
then
  echo -en "\nMongoDB Chart UserAdmin... \n"
  docker exec -it mongo-charts bash -c \
  "charts-cli add-user \
  --first-name "$USERNAME" \
  --last-name \"lab\" \
  --email \"$USERNAME@mail.com\" \
  --password "$PASSWORD" \
  --role \"UserAdmin\""
fi