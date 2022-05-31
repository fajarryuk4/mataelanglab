#!bin/bash

#run as root checker
[[ $(id -u) -eq 0 ]] || { echo >&2 "Please run as root"; exit 1; }

#Requirement checker
command -v docker >/dev/null 2>&1 || { echo >&2 "This service requires Docker, but your computer doesn't have it. Install Docker then try again. Aborting."; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo >&2 "This service requires Docker-Compose, but your computer doesn't have it. Install Docker-Compose then try again. Aborting."; exit 1;}
command -v mosquitto >/dev/null 2>&1 || { echo >&2 "This service requires Mosquitto Broker, but your computer doesn't have it. Install Mosquitto Broker then try again. Aborting."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo >&2 "This service requires curl, but your computer doesn't have it. Install curl then try again. Aborting."; exit 1; }

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

printf "If You have Your own ${YELLOW}DATASET${NC}, please put Your dataset in a folder ${YELLOW}${PWD}/resource${NC}.\n"
printf "So you can access it via ${YELLOW}'/resource'${NC} folder on zeppelin-notebook\n"
read -p "Press any key to resume ..."

echo -e "\nAvailable Network Interface :\n"
netints=`ls -C /sys/class/net`
netints+=("Dummy-Interface")
PS3="Network Interface Card for Tapping"$'\n'"Your Choice(ex: 1): "
select option in ${netints[@]}
do
    if [ -z "$option" ]
    then
      echo -e "Choose a valid choice.\nExited."
      exit 1
    else
      NETINT=$option
      break
    fi
done

if [[ "$NETINT" == *"Dummy"* ]]; then
  ip link add name mel-dummy type dummy
  
  rm -rf /etc/systemd/network/mel-dummy.netdev /etc/systemd/network/mel-dummy.network

  cp scripts/dummy-interface/mel-dummy.netdev  /etc/systemd/network/mel-dummy.netdev
  cp scripts/dummy-interface/mel-dummy.network /etc/systemd/network/mel-dummy.network

  systemctl restart systemd-networkd
  
  NETINT='mel-dummy'
fi

echo -e "\nInput Mongo Chart UserAdmin Account"
read -p "Username: " USERNAME
read -s -p "Password: " PASSWORD

echo -e "\n\nWhat kind Mode do you want to use?\n\t1. Standalone\n\t2. Local Cluster(Under Construction)"
read -p "Your choice : " MELMODE

RULE_CHOICE=1

#Choose commpose mode
if [[ ! $MELMODE -eq 1 && ! $MELMODE -eq 2 ]]; then
  echo -e "Choose a valid choice.\nExited."
  exit 1
fi

if [[ $MELMODE -eq 1 ]]; then
  # echo "Using Standalone MataElangLab.."
  compose_file="docker-compose.yml"
fi

if [[ $MELMODE -eq 2 ]]; then
  # echo "Using Single-Cluster MataElangLab.."
  compose_file="docker-compose-cluster.yml"
fi

while true; do
    echo    # (optional) move to a new line
    read -p "Do You want to use Your own docker-registry[Y/n]? " yn
    case $yn in
        [Yy]* ) 
          echo -e "Ex: 192.168.100.1:5000\n"
          read -p "Docker Registry Address: " DOCREGADD;
          DOCREGADD="$DOCREGADD/";
          sed -i 's/^image:.*/image='$DOCREGADD'/g' $compose_file
          break;;
        [Nn]* ) break;;
        * ) echo -e "Please answer yes or no.\n";;
    esac
done

# if [[ $yn -eq "y" || $yn -eq "Y" ]]; then 
#   sed -i 's|image:\ |image:\ '$DOCREGADD'|g' $compose_file
#   sed -i 's/^image:.*/image='$DOCREGADD'/g' $compose_file
# fi

#============================================================

#Export Folder Project Path
export MEL_PATH=$PWD

#Get NIC IP then override env file
ip4=$(/sbin/ip -o -4 addr list $NETINT | awk '{print $4}' | cut -d/ -f1)
subnet=$(/sbin/ip -o -f inet addr show $NETINT | awk '/scope global/ {print $4}')

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
echo -e "\nAdding rule for port-forwarding"
ufw allow 1883 
ufw allow 7077 

#Remove Exist Volume
rm -rf ./volume/mongochart

#Starting Big Data
echo -e "\nStarting Compose BigData..."
echo "-----------------------------------\ "

#Set Config for Mode
mkdir -p /etc/mataelanglab
cat > /etc/mataelanglab/mode <<EOL
${compose_file}
EOL

docker-compose --file $compose_file up -d

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
    curl -s -X POST -H 'Content-Type: application/json' --data @connector-config/nfm-mongo-sink.json http://localhost:8083/connectors
    curl -s -X POST -H 'Content-Type: application/json' --data @connector-config/snort-mongo-sink.json http://localhost:8083/connectors
    break;
  elif [ "$( docker container inspect -f '{{.State.ExitCode}}' $container_name )" == 1 ]
  then
    echo -en "\n\nSome process has failed to Instance, Please Try Again\n"
    docker-compose --file $compose_file down -v
    exit 1
  fi
done

#Display Available Link
echo -e "\n\n-----------------------------------"
echo -e "${YELLOW}Available WebApp${NC}"
echo -e "(For easier Please Bookmark or Copy link)"
echo -e "-----------------------------------"

#Create Charts users
if [ "$( docker container inspect -f '{{.State.Running}}' mongo-charts )" == "true" ];
then
  echo -en "MongoDB Chart UserAdmin... \n"
  sleep 15
  dbUser=$(
    docker exec -it mongo-charts bash -c \
      "charts-cli add-user \
      --first-name "$USERNAME" \
      --last-name \"lab\" \
      --email \"$USERNAME@mail.com\" \
      --password "$PASSWORD" \
      --role \"UserAdmin\""
  )

  dbUser='GNU/Linux is an operating system'
  SUB='@mail.com'
  if [[ "$STR" == *"$SUB"* ]]; then
    echo "Your Email is $USERNAME@mail.com."
  else
    echo -e "${YELLOW}Failed to add Mongo-Chart User. "
    echo -e "Please wait a minute and create new User again by run command ${NC}'make mongo-user'"
  fi
fi

cat scripts/web-info.txt

nbToken=$((docker exec -it spark-notebook bash -c 'jupyter server list' | rev | cut -d= -f1 | rev) | rev | cut -d: -f3 | rev)
echo -e "http://localhost:8888/${nbToken}"

echo -e "For easier debugging process, You can install portainer"

echo -e "\n\n-----------------------------------"
echo -e "${YELLOW}Setup completed.${NC}"
echo -e "-----------------------------------"
