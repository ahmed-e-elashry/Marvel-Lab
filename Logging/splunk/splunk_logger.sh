#!/bin/bash
#Authors: Jonathan Johnson & Ben Shell
#References: https://stackoverflow.com/ && https://github.com/target/huntlib.git

# Checking to see if script is running as root
if [[ $EUID -ne 0 ]]; then
  echo -e "\x1B[01;31m[X] Script Must Be Run As ROOT\x1B[0m"
   exit 1
fi

echo -e "\x1B[01;34m[*] Setting timezone to UTC..\x1B[0m"

timedatectl set-timezone UTC

read -p 'Input your IP and press [ENTER]: ' Host_IP

# Installing Docker Compose
echo -e "\x1B[01;34m[*] Checking to see if docker is installed\x1B[0m"

if [[ $(which docker-compose) && $(docker-compose --version) ]]; then
    echo -e "\x1B[01;32m[*] Docker Compose is installed\x1B[0m"
  else
   echo -e "\x1B[01;34m[*] Installing Docker Compose\x1B[0m"
    apt-get install docker-compose -y
fi

# Enabling docker service:
echo -e "\x1B[01;34m[*] Enabling Docker Service\x1B[0m"
systemctl enable docker.service

# Pull quick-fleet
echo -e "\x1B[01;34m[*] Cloning/Pulling quick-fleet\x1B[0m"
if [ ! -d "quick-fleet" ]; then
  git clone https://github.com/benjaminshell/quick-fleet.git
else
  (cd quick-fleet; git pull)
fi

# Zeek
read -r -p "Zeek needs a network interface to monitor, would you like to print out your interfaces to see which one to monitor? [y/N] " response

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
	if hash ifconfig 2>/dev/null; then
		ifconfig
	else
		ip address
	fi
else
    echo -e "\x1B[01;34mMoving on..\x1B[0m"
fi

read -p 'Input the network interface you would like zeek to monitor and press [ENTER]: ' Interface
echo -e "\x1B[01;34m[*] Creating Zeek:\x1B[0m"
docker pull blacktop/zeek
if [ "$(docker ps -a -q -f name=zeek)" ]; then
	docker stop zeek && docker rm zeek
fi
docker run -d --name zeek --restart always --cap-add=NET_RAW --net=host -v `pwd`/zeek/zeek-logs/:/pcap:rw -v `pwd`/zeek/__load__.zeek:/usr/local/zeek/share/zeek/base/bif/__load__.zeek blacktop/zeek -i $Interface -C


# Starting containers
echo -e "\x1B[01;34m[*] Starting containers\x1B[0m"
docker-compose -f docker-compose.yml -f quick-fleet/docker-compose.yml up -d
sleep 30 # Wait for splunk to finish installing
# The docker cp is needed after splunk install, otherwise our custom config would be overwritten
docker cp splunk/inputs.conf splunk:/opt/splunk/etc/system/local/inputs.conf
docker restart splunk

rm -rf quick-fleet/result.log/
rm -rf quick-fleet/status.log/
touch quick-fleet/result.log
touch quick-fleet/status.log

# Adding indexes for Splunk: 
docker exec -ti splunk /bin/bash -c 'sudo /opt/splunk/bin/splunk add index Windows'
echo -e "\x1B[01;32m[*] Windows index added!\x1B[0m"
docker exec -ti splunk /bin/bash -c 'sudo /opt/splunk/bin/splunk add index Zeek'
echo -e "\x1B[01;32m[*] Zeek index added!\x1B[0m"
docker exec -ti splunk /bin/bash -c 'sudo /opt/splunk/bin/splunk add index MacOS'
echo -e "\x1B[01;32m[*] MacOS index added!\x1B[0m"
# To remove the containers
# docker-compose -f docker-compose.yml -f quick-fleet/docker-compose.yml down

# Checking Jupyter Notebooks
echo -e "\x1B[01;34m[*] Checking Jupyter Notebooks\x1B[0m"
sleep 10
token="$(docker exec -it jupyter-notebooks sh -c 'jupyter notebook list' | grep token | sed 's/.*token=\([^ ]*\).*/\1/')"
echo -e "\x1B[01;32m[*] Portainer's IP is: http://$Host_IP:9000\x1B[0m"
echo -e "\x1B[01;32m[*] Splunk's IP is: http://$Host_IP:8000 ; Credentials - admin:Changeme1! (unless you changed them in the DockerFile)\x1B[0m"
echo -e "\x1B[01;32m[*] Jupyter Notebook's IP is: http://$Host_IP:8888\x1B[0m"
echo -e "\x1B[01;32m[*] Jupyter Notebook token is $token\x1B[0m"
echo -e "\x1B[01;32m[*] Kolide Fleet's IP is: https://$Host_IP:8443\x1B[0m"

