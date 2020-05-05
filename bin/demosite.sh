#!/usr/bin/env bash
source .env
APP='wordpress'
CONT_NAME='litespeed'
DOC_FD=''
EPACE='        '

echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

help_message(){
    case ${1} in
        "1")   
            echow "Script will get 'DOMAIN' and 'database' info from .env file, then auto setup virtual host and the wordpress site for you."
            echo -e "\033[1mOPTIONS\033[0m"
            echow '-W, --wordpress'
            echo "${EPACE}${EPACE}Example: lsws1clk.sh -W. If no input, script will still install wordpress by default"
            echow '-M, --magento'
            echo "${EPACE}${EPACE}Example: lsws1clk.sh -M"
            echow '-M, --magento -S, --sample'
            echo "${EPACE}${EPACE}Example: lsws1clk.sh -M -S, to install sample data"
            echow '-H, --help'
            echo "${EPACE}${EPACE}Display help and exit." 
        ;;
        "2")
            echow 'Service finished, enjoy your accelarated LiteSpeed server!'
        ;;
    esac       
}

domain_filter(){
    if [ ! -n "${DOMAIN}" ]; then
        echo "Parameters not supplied, please check!"
        exit 1
    fi
    DOMAIN="${1}"
    DOMAIN="${DOMAIN#http://}"
    DOMAIN="${DOMAIN#https://}"
    DOMAIN="${DOMAIN#ftp://}"
    DOMAIN="${DOMAIN#scp://}"
    DOMAIN="${DOMAIN#scp://}"
    DOMAIN="${DOMAIN#sftp://}"
    DOMAIN=${DOMAIN%%/*}
}

gen_root_fd(){
    DOC_FD="./sites/${1}/"
    if [ -d "./sites/${1}" ]; then
        echo -e "[O] The root folder \033[32m${DOC_FD}\033[0m exist."
    else
        echo "Creating - document root."
        bash bin/domain.sh -add ${1}
        echo "Finished - document root."
    fi
}

create_db(){
    if [ ! -n "${MYSQL_DATABASE}" ] || [ ! -n "${MYSQL_USER}" ] || [ ! -n "${MYSQL_PASSWORD}" ]; then
        echo "Parameters not supplied, please check!"
        exit 1
    else    
        bash bin/database.sh -D ${1} -U ${MYSQL_USER} -P ${MYSQL_PASSWORD} -DB ${MYSQL_DATABASE}
    fi    
}    

store_credential(){
    if [ -f ${DOC_FD}/.db_pass ]; then
        echo '[O] db file exist!'
    else
        echo 'Storing database parameter'
        cat > "${DOC_FD}/.db_pass" << EOT
"Database":"${MYSQL_DATABASE}"
"Username":"${MYSQL_USER}"
"Password":"$(echo ${MYSQL_PASSWORD} | tr -d "'")"
EOT
    fi
}

app_download(){
    docker-compose exec ${CONT_NAME} su -c "appinstallctl.sh --app ${1} --domain ${2}"
    docker-compose exec ${CONT_NAME} su -c "install_magentoctl.sh --app ${1} --domain ${2}"
}

lsws_restart(){
    bash bin/webadmin.sh -r
}

main(){
    domain_filter ${DOMAIN}
    gen_root_fd ${DOMAIN}
    create_db ${DOMAIN}
    store_credential
    app_download ${APP} ${DOMAIN}
    lsws_restart
    help_message 2
}

while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message 1
            ;;
        -[wW] | --wordpress)
            APP='wordpress'
            ;;
        -[mM] | --magento)
            APP='magento'
            ;;
        *) 
            help_message 1
            ;;              
    esac
    shift
done
main