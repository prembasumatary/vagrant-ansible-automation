# Simple testcase using Vagrant and Ansible

## Problem Statement and summary of the contents
* Create a `Vagrantfile` that creates a single machine and installs the latest released version of your chosen configuration management tool.
* Install the nginx webserver via configuration management.
* Run a simple test using Vagrant's shell provisioner to ensure that nginx is listening on port 80.
* Again, using configuration management, update contents of /etc/sudoers file so that Vagrant user can sudo without a password and that anyone in the admin group can sudo with a password.
* Make the solution idempotent so that re-running the provisioning step will not restart nginx unless changes have been made.
* Create a simple `Hello World` web application in your favourite language of choice. · Ensure your web application is available via the nginx instance.
* Extend the Vagrantfile to deploy this webapp to two additional vagrant machines and then configure the nginx to load balance between them.
* Test (in an automated fashion) that both app servers are working, and that the nginx is serving the content correctly.


## Assumptions
* A `centos` image has been used (`puppetlabs/centos-7.0-64-nocm`).
* `Ansible` is used as the configuration management tool.
* `vagrant-cachier` plugin has been used to cache packages in buckets (`http://fgrehm.viewdocs.io/vagrant-cachier`).
* `Static inventory` is being used and as the number of servers are known, the private IP addresses have been assigned to each of the VMs.
* The VMs are created at the beginning of the setup itself and is used later to deploy web app onto them.
* The default private key is used and the user is vagrant. The default location of the private key is  `.vagrant/machines/<machine_name>/virtualbox/private_key`
* firewalld service was preventing me to access the web application, so I had to turn it off to access
the app running at port 8080 from the load balancer.
* There is no port conflict with forwarded ports which have been used (although not really needed but it makes checks easy as ideally app servers should not exposed
to outside world and all inbound connections should happen via nginx).
* I have tried to keep it really simple with multiple playbooks for simplicity and ease of understanding.
* The web app is dynamic and is using `Yahoo Weather API` to get the weather details of a location. But it needs a user input in the form of query parameter (`locationId`) which denotes the woeid of the region (this can be looked up here `http://woeid.rosselliot.co.nz`).


## Prerequisites
You should have the following softwares installed in your machines -
* [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
* [Vagrant](https://www.vagrantup.com)


## Install Steps
* Download the compressed tar file into your Downloads directory (~/Downloads).
* Extract the contents of the file by running the command in a terminal window from ~/Downloads directory.
      ```
      tar -xzf vagrant-ansible-automation.tar.gz 
      ```
* In the terminal window, navigate to the `vagrant-ansible-automation` directory.
* Open a terminal window and from the same directory, run `vagrant up`. All the output will be printed to the console.
* Once the whole process is complete, you should have the following -
  * server with hostname `buildserver` an IP `192.168.61.70` running nginx in port 80.
  * 2 app servers (`app1` with IP `192.168.61.71` and `app2` with IP `192.168.61.70`). The weather web app will be deployed into these 2 servers.
  * a weather app which get the weather info given a location id (`woeid`) using Yahoo Weather APIs. The weather app is written in `java` and uses `spring web`, `spring boot` for deployment and `tomcat` as servlet container. The deploy web app play would be installing java in the app servers as a pre-requisite.
  * To get a woeid for a location, search for the location here `http://woeid.rosselliot.co.nz` and then use it with the web-app. To get the weather info for a location, say London, whose woeid is 44418, please use the url `http://192.168.61.70/weather?locationId=44418`. By default, if no locationId is passed, it uses 44418 (london).
  * The weather app is running on port `8080`.
  * nginx is being used to proxy the requests to port 8080.
  * Two more instances (`app1`, IP `192.168.61.71` and `app2`, IP `192.168.61.72`) are created where the  weather app is deployed.
  * nginx is going to load balance requests between the 2 new instances (`app1` and `app2`). And it will output which app server is serving the request.


## Structue of the repository
Wherever possible, all the tasks have been assigned to specific roles (like `nginx-setup`, `deploy-web-app`) and playbooks so that it is easier to understand and also extend in future.
```
├── README.md
├── Vagrantfile
├── ansible.cfg
├── configure-nginx-for-webapp.yml
├── deploy-and-load-balance.yml
├── deploy-web-app.yml
├── install-nginx.yml
├── keys
│   ├── private_key_rsa
│   └── public_key_rsa
├── local.inventory
├── privilege_auth.yml
├── roles
│   ├── java8
│   │   ├── defaults
│   │   │   └── main.yml
│   │   └── tasks
│   │       └── main.yml
│   ├── load-balance
│   │   ├── files
│   │   │   └── load-balancer.conf
│   │   ├── handlers
│   │   │   └── main.yml
│   │   └── tasks
│   │       └── main.yml
│   ├── nginx-config
│   │   ├── files
│   │   │   └── web.conf
│   │   ├── handlers
│   │   │   └── main.yml
│   │   └── tasks
│   │       └── main.yml
│   ├── nginx-setup
│   │   ├── files
│   │   │   └── nginx.conf
│   │   ├── handlers
│   │   │   └── main.yml
│   │   └── tasks
│   │       └── main.yml
│   ├── sudoer
│   │   ├── files
│   │   │   ├── admin_group_policy
│   │   │   └── vagrant_user
│   │   └── tasks
│   │       └── main.yml
│   └── weather-app
│       ├── files
│       │   ├── application.properties
│       │   ├── weather-app.jar
│       │   └── weather-app.service
│       ├── handlers
│       │   └── main.yml
│       ├── meta
│       │   └── main.yml
│       └── tasks
│           └── main.yml
└── scripts
    ├── check-nginx-status.sh
    ├── install_ansible.sh
    └── test-load-balancer.sh
```

## Technical Details
* Vagrantfile starts by creating 3 VMs which we need for this exercise. They have been aptly named to signify their purpose. The file will spin up 3 VMs - 
  * `app1` (**IP 192.168.61.71**) and it is going to be one of the app servers where the webapp will be deployed to.
  * `app2` (**IP 192.168.61.72**) and this is the second app server where webapp will be deployed.
  * `buildserver` (**IP 192.168.61.70**) and is going to act as the load balancer where nginx will be installed and will be used to proxy requests to `app1` and `app2`. This is also
  the server where ansible (our configuration management tool) will be installed.

* vagrant cachier plugin is being used to cache packages whenever possible. It does show slight improvements on following provisions. More details can be obtained from `http://fgrehm.viewdocs.io/vagrant-cachier`.

* A static inventory file is used and logical groups have been created whereever possible. The top level group which has all servers is called `all-hosts` and has 2 children 
`build-server` and `app-servers`.
* The group `build-server` contains 1 server `buildserver` but could contain more if needed in future.
* The group `app-servers` contain 2 app servers app1 and app2.

* Once the `app1` and `app2` have been created, we define `buildserver` which does the bulk of activities.
* First thing after buildserver is created, we'll install ansible on this using the shell provisioner. Every provisioner has been given a name for identification purpose and so that
it can be run alone in some cases when needed. The provisioner script which does the installation is `install_ansible.sh` and can be found under `scripts` directory. Since ansible 
is not available in default RHEL repositories, we are going to use EPEL repository to install ansible.
  ```
    yum -y install epel-release
    yum -y install ansible
  ```

And this is it, it will install ansible on the `buildserver`.

* Then we install `nginx` and start it on the buildserver. This is done by executing `install-nginx.yml` playbook and local.inventory inventory file. This playbook executes the 
role `nginx-setup` which has all the tasks configured to complete the task (of installing ansible). The playbook is executed for `build-server` group only and is run as root 
since nginx installation needs root privileges.
  * nginx.conf config file is replaced during the installation. The changes in the conf include `log_format` changes and including conf files under `conf.d` directory as we'll be
  applying our configs by adding conf files and not updating the default nginx.conf file.
  ```
    log_format  main  '$upstream_addr:$upstream_status';

    include /etc/nginx/conf.d/*.conf;
  ```
* Once nginx is installed, and to test if nginx is running properly and on port 80, we'll run the `check-nginx-status.sh` script which greps the netstat output and applies filter to
get the port as the output. This provisioner has been given a name `check-nginx-port` so that it can be called alone anytime when required.
  ```
    sudo netstat -lntp | grep nginx | awk '{print $4}' | awk -F ":" '{print $2}'
  ```
  * netstat -lnpt | grep nginx is going to return the nginx process if it is running. Something like this -
    ```
    tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      1398/nginx: master
    ```
  * awk '{print $4}' is going to filter the output to only the fourth column (0.0.0.0:80)
  * finally we split the output using : token and extract the second element which correspond to the port
  on which nginx is running.
* The scripts logs appropriate messages to the console to show if nginx is running on port 80 or not. If everything went fine during installation and nginx was up and running, you should
see this output -
    ```
    nginx is running on port 80
    ```
* Next task is to make sure user `vagrant` can sudo without a password and anybody in admin group can sudo with a password. We call a play `privilege_auth.yml` to do this task 
on `build-server` group. This play uses the role `sudoer` which has 2 tasks to update vagrant and admin_group policies. Since it is not recommened to edit the contents of 
file `/etc/sudoers` directly, we'll use the `vagrant_user` file to be copied into `/etc/sudoers.d` directory. We have similar policy called `admin_group_policy` for users 
belonging to group `admin` to be able to sudo with a password.

* Now we'll deploy the weather app into buildserver first and use nginx to proxy requests to the app. The weather app is a springboot based java project and is contained in a 
self-executable jar (`weather-app.jar`) included in the role `weather-app` which is executed by the play `deploy-web-app.yml`. Here you'd see that even though the play uses "all" 
hosts where app will be deployed but this is limited to `build-server` in Vagrantfile during invocation as first we need this deployed only in `buildserver` and test with nginx.
  * We want the app to deployed into `/opt/app/weather` directory so this is what the first task will do.
  * since this is spring applictation, `application.properties` config is used to specify the logging level and control its log location.
  * Also since it will be easier to manage this app as a service, we create a service file and add it to the systemd.
  * the app is essentially contained in a jar, so we copy this into the app directory (/opt/app/weather).
  * finally `firewalld` service is stopped so that nginx can proxy request to it.
  * Since this is java based, it needs java to be installed which is done by adding a dependency `java8` to this role. The `java8` role will install oracle's jdk version `1.8_141` onto 
  the system.
  * the app will be running on port 8080 and its port is forwarded to port 8280 in host, so we can query london's weather to test in browser.
  * Open a browser and go to http://localhost:8280/weather?locationId=44418 or you can use the nginx's server's IP address as well http://192.168.61.70/weather?locationId=44418.

* Next we want to use nginx to acts a proxy for this web app. We'll use the play `configure-nginx-for-webapp.yml` for this. It uses a role `nginx-config` to copy new config `web.conf` 
into the `/etc/nginx/conf.d/` directory and then call handler `reload nginx` to ensure idempotency.
      ```
      server {
        listen 80;
        server_name localhost;
        
        location / {
          proxy_pass http://127.0.0.1:8080;
          proxy_set_header Host $http_host;
        }
      }
      ```

* Next we'll deploy the weather app into `app1` and `app2` servers and use nginx to load balance the requests between the 2 servers. We'll do this with `deploy-and-load-balance` play and
which has 2 plays inside it. We also reuse one of the role `weather-app` to deploy app and have a new role `load-balance` to set up the config required for load-balancing.
  * First one is to deploy app into app1 and app2. This time we limit the execution to only `app-servers` group.
  * Once the web app has been deployed, we configure nginx to load balance requests. This is done by round-robin config and is defined in role `load-balancer.conf` -

        upstream weather-app {

            server 192.168.61.71:8080;
            server 192.168.61.72:8080;
        }

        server {
            listen 80;
            server_name localhost;

            location / {
                proxy_pass http://weather-app;
            }
        } 
  * once the config is copied, nginx is reload and restarted.

* Finally we check if the load balancing is okay or not by running the shell script `test-load-balancer.sh`. Again this provisioner has been given a name so that it can be called 
alone anytime required. The script outputs `Request served from <node_ip_address>` in the console when run. It will send 6 requests to the load balancer and will output the IP 
address of the node which served the requests. If the nginx load balancing was working fine, we should see an even split between the 2 app servers and this the output should 
look like this -
        ```
          ==> buildserver: Accessing weather information for london and sending  requests to weather app..
          ==> buildserver: Request served from 192.168.61.71
          ==> buildserver: Request served from 192.168.61.72
          ==> buildserver: Request served from 192.168.61.71
          ==> buildserver: Request served from 192.168.61.72
          ==> buildserver: Request served from 192.168.61.71
          ==> buildserver: Request served from 192.168.61.72
        ```
* This deployment in 2 servers and then start of the service could take a little while and some occasions, nginx might not be able to proxy to app1 and app2. In that case,
please run the provisioner to test load balance after some delay, by using this command from the project's root level directory-
      ```
      vagrant provision buildserver --provision-with test-load-balancer
      ```
## Troubleshooting
* I had some issues with the `firewall` daemon running in app1 and app2, so had to disable it to be used for load balancing.

## Improvements
* Dynamic inventory could be used for Cloud Provisioning.
* different keys could be used for managing access to servers.
* Also different users, groups and roles could be used.
* The load balancing algorithm could be changed, I've used the default round robin fashion to keep it simple.
* a single configuration could have been applied to create the 3 VMs.