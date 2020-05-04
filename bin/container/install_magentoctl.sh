#!/bin/bash
# /***************************************************************
# LiteSpeed Latest
# WordPress Latest 
# Magento stable
# LSCache Latest 
# PHP 7.3 
# MariaDB 10.4
# Memcached stable
# Redis stable
# PHPMyAdmin Latest
# ****************************************************************/
### Author: Cold Egg & Lars Hagen

CMDFD='/opt'
WWWFD='/var/www'
DOCROOT='/var/www/vhosts/localhost/html'
PHPMYFD='/var/www/phpmyadmin'
PHPMYCONF="${PHPMYFD}/config.inc.php"
LSDIR='/usr/local/lsws'
LSCONF="${LSDIR}/conf/httpd_config.xml"
LSVCONF="${LSDIR}/DEFAULT/conf/vhconf.xml"
USER='1000'
GROUP='lsadm'
THEME='twentytwenty'
MARIAVER='10.4'
PHPVER='73'
PHP_M='7'
PHP_S='3'
FIREWALLLIST="22 80 443"
PHP_MEMORY='777'
PHP_BIN="${LSDIR}/lsphp${PHPVER}/bin/lsphp"
PHPINICONF=""
WPCFPATH="${DOCROOT}/wp-config.php"
REPOPATH=''
WP_CLI='/usr/local/bin/wp'
MA_COMPOSER='/usr/local/bin/composer'
MA_VER='2.3.4'
OC_VER='3.0.3.2'
EMAIL='test@example.com'
APP_ACCT='admin123'
APP_PASS='password456'
MA_BACK_URL='admin_123'
OC_BACK_URL='admin'
MEMCACHECONF=''
REDISSERVICE=''
REDISCONF=''
WPCONSTCONF="${DOCROOT}/wp-content/plugins/litespeed-cache/data/const.default.ini"
PLUGIN='litespeed-cache.zip'
BANNERNAME='wordpress'
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
BANNERDST=''
SKIP_WP=0
SKIP_REDIS=0
SKIP_MEMCA=0
app_skip=0
SAMPLE='false'
OSNAMEVER=''
OSNAME=''
OSVER=''
APP='wordpress'
DB_NAME='wordpress'
DB_USER='wordpress'
DB_PASSWORD='password'
DB_HOST='mysql'

set_mariadb_root(){
    SQLVER=$(mysql -u root -e 'status' | grep 'Server version')
    SQLVER_1=$(echo ${SQLVER} | awk '{print substr ($3,1,2)}')
    SQLVER_2=$(echo ${SQLVER} | awk -F '.' '{print $2}')
    if (( ${SQLVER_1} >=11 )); then
        mysql -u root -e "ALTER USER root@localhost IDENTIFIED VIA mysql_native_password USING PASSWORD('${MYSQL_ROOT_PASS}');"
    elif (( ${SQLVER_1} ==10 )) && (( ${SQLVER_2} >=4 && ${SQLVER_2}<=9 )); then
        mysql -u root -e "ALTER USER root@localhost IDENTIFIED VIA mysql_native_password USING PASSWORD('${MYSQL_ROOT_PASS}');"
    elif (( ${SQLVER_1} ==10 )) && (( ${SQLVER_2} ==3 )); then
        mysql -u root -e "UPDATE mysql.user SET authentication_string = '' WHERE user = 'root';"
        mysql -u root -e "UPDATE mysql.user SET plugin = '' WHERE user = 'root';"  
    elif (( ${SQLVER_1} == 10 )) && (( ${SQLVER_2} == 2 )); then
        mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${MYSQL_ROOT_PASS}');"
    else
        echo 'Please check DB version!'
        mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';"
    fi
}
set_mariadb_user(){
    mysql -u root -p${MYSQL_ROOT_PASS} -e "DELETE FROM mysql.user WHERE User = '${WP_USER}';"
    mysql -u root -p${MYSQL_ROOT_PASS} -e "CREATE DATABASE IF NOT EXISTS ${WP_NAME};"
    if [ ${?} = 0 ]; then
        mysql -u root -p${MYSQL_ROOT_PASS} -e "grant all privileges on ${WP_NAME}.* to '${WP_USER}'@'localhost' identified by '${WP_PASS}';"
    else
        echoR "Failed to create database ${WP_NAME}. It may already exist. Skip WordPress setup!"
        SKIP_WP=1
    fi
}

set_db_user(){
    mysql -u root -e 'status'
    if [ ${?} = 0 ]; then
        set_mariadb_root
        WP_NAME="${APP}"
        WP_USER="${APP}"      
        WP_PASS="${MYSQL_USER_PASS}"
        cd ${DOCROOT}
        set_mariadb_user
    else
        echoR 'DB access failed, skip app setup!'
        app_skip=1
    fi    
}

www_user_pass(){
    LINENUM=$(grep -n -m1 www-data /etc/passwd | awk -F ':' '{print $1}')
    sed -i "${LINENUM}s|/usr/sbin/nologin|/bin/bash|" /etc/passwd
}

echoY() {
    echo -e "\033[38;5;148m${1}\033[39m"
}
echoG() {
    echo -e "\033[38;5;71m${1}\033[39m"
}
echoR()
{
    echo -e "\033[38;5;203m${1}\033[39m"
}
echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}


install_composer(){
    if [ -e ${MA_COMPOSER} ]; then
        echoG 'Composer already installed'
    else
        curl -sS https://getcomposer.org/installer | php
        mv composer.phar ${MA_COMPOSER}
        composer --version
        if [ ${?} != 0 ]; then
            echoR 'Issue with composer, Please check!'
        fi        
    fi    
}


ubuntu_pkg_mariadb(){
    #apt list --installed 2>/dev/null | grep mariadb-server-${MARIAVER} >/dev/null 2>&1
    apt-get install software-properties-common -y

    add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mirror.netinch.com/pub/mariadb/repo/10.3/ubuntu xenial main'

    apt update

    apt install mariadb-server -y

    #systemctl start mariadb
    /usr/bin/mysqld_safe &


}
create_vhost(){

    mkdir -p /var/www/vhosts/localhost/html/ 
    #&& /usr/local/lsws/bin/lswsctrl restart >/dev/null 
}
change_owner(){
    echoG 'Change Owner'
    chown -R ${USER}:${GROUP} ${1}
}

install_magento(){
    # if [ -e ${DOCROOT}/index.php ]; then
    #     echoR "${DOCROOT}/index.php exist, skip."
    # else
        install_composer
        rm -f ${MA_VER}.tar.gz
        wget -q --no-check-certificate https://github.com/magento/magento2/archive/${MA_VER}.tar.gz
        if [ ${?} != 0 ]; then
            echoR "Download ${MA_VER}.tar.gz failed, abort!"
            exit 1
        fi    
        tar -zxf ${MA_VER}.tar.gz
        mv magento2-${MA_VER}/* ${DOCROOT}
        mv magento2-${MA_VER}/.editorconfig ${DOCROOT}
        mv magento2-${MA_VER}/.htaccess ${DOCROOT}
        mv magento2-${MA_VER}/.php_cs.dist ${DOCROOT}
        mv magento2-${MA_VER}/.user.ini ${DOCROOT}
        rm -rf ${MA_VER}.tar.gz magento2-${MA_VER}
        echoG 'Finished Composer install'
        #www_user_pass
        #set_db_user
        if [ ${app_skip} = 0 ]; then
            echoG 'Run Composer install'
            echo -ne '\n' | composer install
            echoG 'Composer install finished'
            if [ ! -e ${DOCROOT}/vendor/autoload.php ]; then
                echoR "/vendor/autoload.php not found, need to check"
                sleep 10
                ls ${DOCROOT}/vendor/
            fi    
            echoG 'Install Magento...'
            ./bin/magento setup:install \
                --db-name=${DB_NAME} \
                --db-user=${DB_USER} \
                --db-password=${DB_PASSWORD} \
                --db-host=${DB_HOST} \
                --admin-user=${APP_ACCT} \
                --admin-password=${APP_PASS} \
                --admin-email=${EMAIL} \
                --admin-firstname=test \
                --admin-lastname=account \
                --language=en_US \
                --currency=USD \
                --timezone=America/Chicago \
                --use-rewrites=1 \
                --backend-frontname=${MA_BACK_URL}
            if [ ${?} = 0 ]; then
                echoG 'Magento install finished'
            else
                echoR 'Not working properly!'    
            fi 
            change_owner ${DOCROOT}
        fi    
    # fi
}


    #ubuntu_pkg_basic
    #ubuntu_pkg_postfix
    #ubuntu_pkg_memcached
    #ubuntu_pkg_redis
    #ubuntu_pkg_ufw
    #ubuntu_pkg_phpmyadmin
    ##ubuntu_pkg_certbot
    #ubuntu_pkg_system
    #create_vhost
#ubuntu_pkg_mariadb
#install_composer
install_magento
#install_composer