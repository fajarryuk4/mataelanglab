#!bin/bash

#run as root checker
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

#Requirement checker
command -v docker >/dev/null 2>&1 || { echo >&2 "This service requires Docker, but your computer doesn't have it. Install Docker then try again. Aborting."; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo >&2 "This service requires Docker-Compose, but your computer doesn't have it. Install Docker-Compose then try again. Aborting."; exit 1;}
command -v mosquitto >/dev/null 2>&1 || { echo >&2 "This service requires Mosquitto Broker, but your computer doesn't have it. Install Mosquitto Broker then try again. Aborting."; exit 1; }

#Opening
printf '
 __  __    _  _____  _       _____ _        _    _   _  ____    _        _    ____
|  \/  |  / \|_   _|/ \     | ____| |      / \  | \ | |/ ___|  | |      / \  | __ )
| |\/| | / _ \ | | / _ \    |  _| | |     / _ \ |  \| | |  _   | |     / _ \ |  _ \
| |  | |/ ___ \| |/ ___ \   | |___| |___ / ___ \| |\  | |_| |  | |___ / ___ \| |_) |
|_|  |_/_/   \_|_/_/   \_\  |_____|_____/_/   \_|_| \_|\____|  |_____/_/   \_|____/'

echo -e "\n"
echo ----------------------------------------------------------
echo -e "\tBigData Platform for Network Research"
echo ----------------------------------------------------------
echo -e "\n"

YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#Note
echo -----------
printf "${YELLOW}Warning: ${NC}If Using Virtual Machine, Please use NAT Mode\n"
echo -e "-----------\n"

#All input
#===========================================================
echo "Available Network Interface : `ls -C /sys/class/net`"
echo "Network Interface Card for Tapping (ex: eth0)"
read -p "Your Choice: " NETINT

echo -e "\nInput Mongo Chart UserAdmin Account"
read -p "Username: " USERNAME
read -s -p "Password: " PASSWORD

echo -e "\n\nWhat kind Mode do you want to use?\n\t1. Standalone\n\t2. Spark-Cluster \n\t3. Spark-Hive-Cluster(Coming Soon)"
read -p "Your choice : " MELMODE

RULE_CHOICE=1

#Choose commpose mode
if [[ ! $MELMODE -eq 1 && ! $MELMODE -eq 2 ]]; then
  echo -e "Choose a valid choice.\nExited."
  exit 1
fi

if [[ $MELMODE -eq 3 ]]; then
  echo -e "Sorry, Still Under Construction.\nExited."
  exit 1
fi
#============================================================

#Get NIC IP then override env file
ip4=$(/sbin/ip -o -4 addr list $NETINT | awk '{print $4}' | cut -d/ -f1)
subnet=$(/sbin/ifconfig $NETINT | awk '/Mask:/{ print $4;} ')

##Netflowmeter
sed -i 's/^NETINT=.*/NETINT='$NETINT'/' envfile/netflowmeter.env
sed -i 's/^MQTT_HOST=.*/MQTT_HOST='$ip4'/' envfile/netflowmeter.env
##Snort
sed -i 's/^PROTECTED_SUBNET=.*/PROTECTED_SUBNET='$subnet'\/24/' envfile/snort.env 
sed -i 's/^ALERT_MQTT_SERVER=.*/ALERT_MQTT_SERVER='$ip4'/' envfile/snort.env
sed -i 's/^NETINT=.*/NETINT='$NETINT'/' envfile/snort.env

#Running MQTT
systemctl start mosquitto

#Allow mqqt in firewall
echo -e "\n\nAdding rule for MQTT transfer file"
ufw allow 1883 

#Remove Exist Volume
rm -rf ./volume/mongochart ./spark ./notebooks

#Starting Big Data
echo -e "\nStarting Compose BigData..."
echo "-----------------------------------\ "

if [[ $MELMODE -eq 1 ]]; then
  echo "Using Standalone MataElangLab.."
  docker-compose up -d
fi

if [[ $MELMODE -eq 2 ]]; then
  echo "Using Single-Cluster MataElangLab.."
  docker-compose --file docker-compose-spark.yml up -d
fi

if [[ $MELMODE -eq 3 ]]; then
  echo "Using Hadoop-Cluster MataElangLab.."
  docker-compose --file docker-compose-hive.yml up -d
fi

echo -----------------------------------/
chars="/-\|"
container_name="connect"

#Set MQTT IP in confluent-config file for connection between Kafka-MQTT
sed -i 's|tcp://.*|tcp://'$ip4':1883",|' connector-config/nfm-connector.json
sed -i 's|tcp://.*|tcp://'$ip4':1883",|' connector-config/snort-connector.json

while [ "$( docker container inspect -f '{{.State.Running}}' $container_name )" == "true" ];
do
  for (( i=0; i<${#chars}; i++ )); do
    sleep 0.1
    echo -en "Configuring Kafka Connector...[${chars:$i:1}]" "\r"
  done

  if [ "$( docker container inspect -f '{{.State.Health.Status}}' $container_name )" == "healthy" ]
  then
    curl -s -X POST -H 'Content-Type: application/json' --data @connector-config/nfm-connector.json http://localhost:8083/connectors
    curl -s -X POST -H 'Content-Type: application/json' --data @connector-config/snort-connector.json http://localhost:8083/connectors
    break;
  fi
done

docker exec -u 0 -it apache-zeppelin bash -c "passwd -d zeppelin"

#Display Available Link
echo -e "\n\n-----------------------------------"
echo -e "${YELLOW}Available WebApp${NC}"
echo -e "(For easier Please Bookmark or Copy link)"
echo -e "-----------------------------------"

echo -e "MongoDB-URL\t\t mongodb://mongodb:27017"
echo -e "Mongo Chart Panel\t http://0.0.0.0:8280/"
#Create Charts users
if [ "$( docker container inspect -f '{{.State.Running}}' mongo-charts )" == "true" ];
then
  echo -en "MongoDB Chart UserAdmin... \n"
  sleep 10
  docker exec -it mongo-charts bash -c \
  "charts-cli add-user \
  --first-name "$USERNAME" \
  --last-name \"lab\" \
  --email \"$USERNAME@mail.com\" \
  --password "$PASSWORD" \
  --role \"UserAdmin\""
fi

echo -e "\nKafka Control Center\t http://0.0.0.0:9021/"
echo -e "Spark-Panel\t\t http://0.0.0.0:8181/"
echo -e "Zeppelin-Notebook\t http://0.0.0.0:8180/"
echo -e "Place Your csv dataset in "$pwd"/resource"

if [[ $MELMODE -eq 3 ]]; then
  echo -e "Hadoop-Panel\t http://0.0.0.0:8181/"
fi

echo -e "\n\n-----------------------------------"
echo -e "${YELLOW}Setup completed.${NC}"
echo -e "-----------------------------------"
