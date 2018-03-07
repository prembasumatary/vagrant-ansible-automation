#!/bin/bash

# Add EPEL7 package repository
yum -y install epel-release
yum -y install ansible || (echo "Ansible failed to install."; exit 1)