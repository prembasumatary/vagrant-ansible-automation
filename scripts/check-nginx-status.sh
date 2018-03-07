# store port on which nginx is running
nginx_port=$(sudo netstat -lntp | grep nginx | awk '{print $4}' | awk -F ":" '{print $2}')
if [ "$nginx_port"=="80" ]; then
	echo "nginx is running on port 80"
else 
	echo "nginx is not running on port 80"
fi
exit 0