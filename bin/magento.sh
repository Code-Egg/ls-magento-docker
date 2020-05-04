#!/usr/bin/env bash

docker-compose exec litespeed su -c "cd /var/www/vhosts/localhost/html/ && install_magentoctl.sh"
bash bin/webadmin.sh -r

          