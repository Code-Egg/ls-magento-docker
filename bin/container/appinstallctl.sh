#!/bin/bash

DEFAULT_VH_ROOT='/var/www/vhosts'
VH_DOC_ROOT=''
APP=''
DOMAIN=''
WWW_UID=''
WWW_GID=''
USER='1000'
WP_CONST_CONF=''
DB_HOST='mysql'
PLUGINLIST="litespeed-cache.zip"
THEME='twentytwenty'
LSDIR='/usr/local/lsws'
PHP_MEMORY='777'
MA_COMPOSER='/usr/local/bin/composer'
MA_VER='2.3.4'
EMAIL='test@example.com'
APP_ACCT=''
APP_PASS=''
MA_BACK_URL=''
SKIP_WP=0
app_skip=0
SAMPLE='false'
EPACE='        '

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

help_message(){
	echo -e "\033[1mOPTIONS\033[0m"
    echow '-A, -app [wordpress|magento] -D, --domain [DOMAIN_NAME]'
    echo "${EPACE}${EPACE}Example: appinstallctl.sh --app wordpress --domain example.com"
	echow '-A, -app [wordpress|magento] -D, --domain [DOMAIN_NAME] -S, --sample'
	echo "${EPACE}${EPACE}Example: appinstallctl.sh --app magento --domain example.com --sample"	
    echow '-H, --help'
    echo "${EPACE}${EPACE}Display help and exit."
    exit 0
}

check_input(){
    if [ -z "${1}" ]; then
        help_message
        exit 1
    fi
}

linechange(){
    LINENUM=$(grep -n "${1}" ${2} | cut -d: -f 1)
    if [ -n "${LINENUM}" ] && [ "${LINENUM}" -eq "${LINENUM}" ] 2>/dev/null; then
        sed -i "${LINENUM}d" ${2}
        sed -i "${LINENUM}i${3}" ${2}
    fi 
}

ck_ed(){
    if [ ! -f /bin/ed ]; then
        echo 'ed package not exist, please check!'
		exit 1
    fi    
}

ck_unzip(){
    if [ ! -f /usr/bin/unzip ]; then 
        echo 'unzip package not exist, please check!'
		exit 1
    fi		
}

gen_pass(){
	APP_STR=$(shuf -i 100-999 -n1)
    APP_PASS=$(openssl rand -hex 16)
	APP_ACCT="admin${APP_STR}"
	MA_BACK_URL="admin_${APP_STR}"
}

get_owner(){
	WWW_UID=$(stat -c "%u" ${DEFAULT_VH_ROOT})
	WWW_GID=$(stat -c "%g" ${DEFAULT_VH_ROOT})
	if [ ${WWW_UID} -eq 0 ] || [ ${WWW_GID} -eq 0 ]; then
		WWW_UID=1000
		WWW_GID=1000
		echo "Set owner to ${WWW_UID}"
	fi
}

check_composer(){
    if [ -e ${MA_COMPOSER} ]; then
        echoG 'Composer already installed'
    else
        echoR 'Issue with composer, Please check!'    
    fi    
}

check_git(){
	if [ ! -e /usr/bin/git ]; then
		echoG 'git package not exist, please check!'
    fi
}

get_db_pass(){
	if [ -f ${DEFAULT_VH_ROOT}/${1}/.db_pass ]; then
		SQL_DB=$(grep -i Database ${VH_ROOT}/.db_pass | awk -F ':' '{print $2}' | tr -d '"')
		SQL_USER=$(grep -i Username ${VH_ROOT}/.db_pass | awk -F ':' '{print $2}' | tr -d '"')
		SQL_PASS=$(grep -i Password ${VH_ROOT}/.db_pass | awk -F ':' '{print $2}' | tr -d '"')
	else
		echo 'db pass file can not locate, skip wp-config pre-config.'
	fi
}

set_vh_docroot(){
    if [ -d ${DEFAULT_VH_ROOT}/${1}/html ]; then
	    VH_ROOT="${DEFAULT_VH_ROOT}/${1}"
        VH_DOC_ROOT="${DEFAULT_VH_ROOT}/${1}/html"
		WP_CONST_CONF="${VH_DOC_ROOT}/wp-content/plugins/litespeed-cache/data/const.default.ini"
	else
	    echo "${DEFAULT_VH_ROOT}/${1}/html does not exist, please add domain first! Abort!"
		exit 1
	fi	
}

check_sql_native(){
	local COUNTER=0
	local LIMIT_NUM=100
	until [ "$(curl -v mysql:3306 2>&1 | grep native)" ]; do
		echo "Counter: ${COUNTER}/${LIMIT_NUM}"
		COUNTER=$((COUNTER+1))
		if [ ${COUNTER} = 10 ]; then
			echo '--- MySQL is starting, please wait... ---'
		elif [ ${COUNTER} = ${LIMIT_NUM} ]; then	
			echo '--- MySQL is timeout, exit! ---'
			exit 1
		fi
		sleep 1
	done
}

install_wp_plugin(){
    for PLUGIN in ${PLUGINLIST}; do
        wget -q -P ${VH_DOC_ROOT}/wp-content/plugins/ https://downloads.wordpress.org/plugin/${PLUGIN}
        if [ ${?} = 0 ]; then
		    ck_unzip
            unzip -qq -o ${VH_DOC_ROOT}/wp-content/plugins/${PLUGIN} -d ${VH_DOC_ROOT}/wp-content/plugins/
        else
            echo "${PLUGINLIST} FAILED to download"
        fi
    done
    rm -f ${VH_DOC_ROOT}/wp-content/plugins/*.zip
}

config_wp_htaccess(){
    if [ ! -f ${VH_DOC_ROOT}/.htaccess ]; then 
        touch ${VH_DOC_ROOT}/.htaccess
    fi   
    cat << EOM > ${VH_DOC_ROOT}/.htaccess
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOM
}

set_lscache(){ 
    cat << EOM > "${WP_CONST_CONF}" 
; This is the default LSCWP configuration file
; All keys and values please refer const.cls.php
; Here just list some examples
; Comments start with \`;\`
; OPID_PURGE_ON_UPGRADE
purge_upgrade = true
; OPID_CACHE_PRIV
cache_priv = true
; OPID_CACHE_COMMENTER
cache_commenter = true
;Object_Cache_Enable
cache_object = true
; OPID_CACHE_OBJECT_HOST
;cache_object_host = 'localhost'
cache_object_host = '/var/www/memcached.sock'
; OPID_CACHE_OBJECT_PORT
;cache_object_port = '11211'
cache_object_port = ''
auto_upgrade = true
; OPID_CACHE_BROWSER_TTL
cache_browser_ttl = 2592000
; OPID_PUBLIC_TTL
public_ttl = 604800
; ------------------------------CDN Mapping Example BEGIN-------------------------------
; Need to add the section mark \`[litespeed-cache-cdn_mapping]\` before list
;
; NOTE 1) Need to set all child options to make all resources to be replaced without missing
; NOTE 2) \`url[n]\` option must have to enable the row setting of \`n\`
;
; To enable the 2nd mapping record by default, please remove the \`;;\` in the related lines
[litespeed-cache-cdn_mapping]
url[0] = ''
inc_js[0] = true
inc_css[0] = true
inc_img[0] = true
filetype[0] = '.aac
.css
.eot
.gif
.jpeg
.js
.jpg
.less
.mp3
.mp4
.ogg
.otf
.pdf
.png
.svg
.ttf
.woff'
;;url[1] = 'https://2nd_CDN_url.com/'
;;filetype[1] = '.webm'
; ------------------------------CDN Mapping Example END-------------------------------
EOM

    if [ ! -f ${VH_DOC_ROOT}/wp-content/themes/${THEME}/functions.php.bk ]; then 
        cp ${VH_DOC_ROOT}/wp-content/themes/${THEME}/functions.php ${VH_DOC_ROOT}/wp-content/themes/${THEME}/functions.php.bk
        ck_ed
        ed ${VH_DOC_ROOT}/wp-content/themes/${THEME}/functions.php << END >>/dev/null 2>&1
2i
require_once( WP_CONTENT_DIR.'/../wp-admin/includes/plugin.php' );
\$path = 'litespeed-cache/litespeed-cache.php' ;
if (!is_plugin_active( \$path )) {
    activate_plugin( \$path ) ;
    rename( __FILE__ . '.bk', __FILE__ );
}
.
w
q
END
    fi
}

preinstall_wordpress(){
	get_db_pass ${DOMAIN}
	if [ ! -f ${VH_DOC_ROOT}/wp-config.php ] && [ -f ${VH_DOC_ROOT}/wp-config-sample.php ]; then
		cp ${VH_DOC_ROOT}/wp-config-sample.php ${VH_DOC_ROOT}/wp-config.php
		NEWDBPWD="define('DB_PASSWORD', '${SQL_PASS}');"
		linechange 'DB_PASSWORD' ${VH_DOC_ROOT}/wp-config.php "${NEWDBPWD}"
		NEWDBPWD="define('DB_USER', '${SQL_USER}');"
		linechange 'DB_USER' ${VH_DOC_ROOT}/wp-config.php "${NEWDBPWD}"
		NEWDBPWD="define('DB_NAME', '${SQL_DB}');"
		linechange 'DB_NAME' ${VH_DOC_ROOT}/wp-config.php "${NEWDBPWD}"
		NEWDBPWD="define('DB_HOST', '${DB_HOST}');"
		linechange 'DB_HOST' ${VH_DOC_ROOT}/wp-config.php "${NEWDBPWD}"
	elif [ -f ${VH_DOC_ROOT}/wp-config.php ]; then
		echo "${VH_DOC_ROOT}/wp-config.php already exist, exit !"
		exit 1
	else
		echo 'Skip!'
		exit 2
	fi 
}

app_wordpress_dl(){
	if [ ! -f "${VH_DOC_ROOT}/wp-config.php" ] && [ ! -f "${VH_DOC_ROOT}/wp-config-sample.php" ]; then
		wp core download \
			--allow-root \
			--quiet
	else
	    echo 'wordpress already exist, abort!'
		exit 1
	fi
}

clean_magento_cache(){
    cd ${VH_DOC_ROOT}
    php bin/magento cache:flush >/dev/null 2>&1
    php bin/magento cache:clean >/dev/null 2>&1
}

config_ma_htaccess(){
    echoG 'Setting Magento htaccess'
    if [ ! -f ${VH_DOC_ROOT}/.htaccess ]; then
        echoR "${VH_DOC_ROOT}/.htaccess not exist, skip"
    else
        sed -i '1i\<IfModule LiteSpeed>LiteMage on</IfModule>\' ${VH_DOC_ROOT}/.htaccess
    fi
}

install_litemage(){
    echoG '[Start] Install LiteMage'
    echo -ne '\n' | composer require litespeed/module-litemage
    bin/magento deploy:mode:set developer; 
    bin/magento module:enable Litespeed_Litemage; 
    bin/magento setup:upgrade;
    bin/magento setup:di:compile; 
    bin/magento deploy:mode:set production;
    echoG '[End] LiteMage install'
    clean_magento_cache
}

config_litemage(){
    bin/magento config:set --scope=default --scope-code=0 system/full_page_cache/caching_application LITEMAGE
}

app_magento_dl(){
	rm -f ${MA_VER}.tar.gz
	wget -q --no-check-certificate https://github.com/magento/magento2/archive/${MA_VER}.tar.gz
	if [ ${?} != 0 ]; then
		echoR "Download ${MA_VER}.tar.gz failed, abort!"
		exit 1
	fi
	tar -zxf ${MA_VER}.tar.gz
	mv magento2-${MA_VER}/* ${VH_DOC_ROOT}
	mv magento2-${MA_VER}/.editorconfig ${VH_DOC_ROOT}
	mv magento2-${MA_VER}/.htaccess ${VH_DOC_ROOT}
	mv magento2-${MA_VER}/.php_cs.dist ${VH_DOC_ROOT}
	mv magento2-${MA_VER}/.user.ini ${VH_DOC_ROOT}
	rm -rf ${MA_VER}.tar.gz magento2-${MA_VER}		
}

install_magento(){
	if [ ${app_skip} = 0 ]; then
		echoG 'Run Composer install'
		echo -ne '\n' | composer install
		echoG 'Composer install finished'
		if [ ! -e ${VH_DOC_ROOT}/vendor/autoload.php ]; then
			echoR "/vendor/autoload.php not found, need to check"
			sleep 10
			ls ${VH_DOC_ROOT}/vendor/
		fi
		get_db_pass ${DOMAIN}
		echoG 'Install Magento...'
		./bin/magento setup:install \
			--db-name=${SQL_DB} \
			--db-user=${SQL_USER} \
			--db-password=${SQL_PASS} \
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
		change_owner ${VH_DOC_ROOT}
		echo "Set owner to ${VH_DOC_ROOT}"
		echo "Set owner to ${WWW_UID}"
		echo "Set owner to ${WWW_GID}"
	fi
}

install_ma_sample(){
    if [ "${SAMPLE}" = 'true' ]; then
        echoG 'Start installing Magento 2 sample data'
        git clone https://github.com/magento/magento2-sample-data.git
        cd magento2-sample-data
        git checkout ${MA_VER}
        php -f dev/tools/build-sample-data.php -- --ce-source="${VH_DOC_ROOT}"
        echoG 'Update permission'
        change_owner ${VH_DOC_ROOT}; cd ${VH_DOC_ROOT}
        find . -type d -exec chmod g+ws {} +
        rm -rf var/cache/* var/page_cache/* var/generation/*
        echoG 'Upgrade'
        su ${USER} -c 'php bin/magento setup:upgrade'
        echoG 'Deploy static content'
        su ${USER} -c 'php bin/magento setup:static-content:deploy'
        echoG 'End installing Magento 2 sample data'
    fi
}

change_owner(){
	    chown -R ${WWW_UID}:${WWW_GID} ${DEFAULT_VH_ROOT}/${DOMAIN}
}

show_access(){
	echo "Account: ${APP_ACCT}"
	echo "Password: ${APP_PASS}"
	echo "Admin_URL: ${MA_BACK_URL}"
}

main(){
	set_vh_docroot ${DOMAIN}
	get_owner
	gen_pass
	cd ${VH_DOC_ROOT}
	if [ "${APP}" = 'wordpress' ] || [ "${APP}" = 'W' ]; then
		check_sql_native
		app_wordpress_dl
		preinstall_wordpress
		install_wp_plugin
		config_wp_htaccess
		set_lscache
		change_owner
		exit 0
	elif [ "${APP}" = 'magento' ] || [ "${APP}" = 'M' ]; then	
		check_composer
		check_git
		app_magento_dl
		install_magento
		install_litemage
		config_ma_htaccess
        config_litemage
		install_ma_sample
		change_owner
		show_access
		exit 0	
	else
		echo "APP: ${APP} not support, exit!"
		exit 1	
	fi
}

check_input ${1}
while [ ! -z "${1}" ]; do
	case ${1} in
		-[hH] | -help | --help)
			help_message
			;;
		-[aA] | -app | --app) shift
			check_input "${1}"
			APP="${1}"
			;;
		-[dD] | -domain | --domain) shift
			check_input "${1}"
			DOMAIN="${1}"
			;;
		-[sS] | --sample)
            SAMPLE='true'
            ;;			      
		*) 
			help_message
			;;              
	esac
	shift
done
main
