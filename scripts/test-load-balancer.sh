#!/bin/bash

# number of requests fired
num_requests=6
#to allow service to be up and running.
sleep 15
echo "Accessing weather information for london and sending $requests requests to weather app.."

counter=0
while [ $counter  -le $num_requests ];
do
    # the nginx log format is node_ip_address:port:status_code
    # extract the IP address from the log
    # woeid of 44418 belongs to london region, UK
    output=$(curl -s http://192.168.61.70/weather?locationId=44418)
    node_ip_address=$(tail -1 /var/log/nginx/access.log | awk -F ":" '{print $1}')
    echo "Request served from $node_ip_address"
    ((counter++))
done
exit 0