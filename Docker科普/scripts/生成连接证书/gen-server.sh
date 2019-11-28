#!/usr/bin/env bash

PASS=
Country=CN
State=Beijing
Locality=Beijing
Organization=SHX
Unit=TechEdu
CommonName=si_he_xiang.github.com
EMAIL=

Usage(){
    cat <<EOF

Usage: $0 <--pass> <--email> <[--domain] [--ip] [--altauto]>... [OPTIONS]

生成Docker使用的CA和服务端证书

Requires:
  --pass string             CA的签名密码
  --email string            用于管理证书的邮箱,CA根证书中的"Email Address"
  --domain string           服务器接受访问的域名(altName),允许多值
  --ip string               服务器接受访问的IP地址(altName),允许多值
  --altauto                 自动生成altName

Options:
  --country string          CA根证书中的"Country Name",缺省值"${Country}"
  --state string            CA根证书中的"State or Province Name",缺省值"${State}"
  --locality string         CA根证书中的"Locality Name",缺省值"${Locality}"
  --organization string     CA根证书中的"Organization Name",缺省值"${Organization}"
  --unit string             CA根证书中的"Organizational Unit Name",缺省值"${Unit}"
  --commonname string       CA根证书中的"Common Name",缺省值"${CommonName}"
EOF
    exit 1
}

command_error(){
  echo "$1 参数值不能为空"
  exit 1
}



if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
  Usage
fi




ALT_NAME=IP:127.0.0.1
ACCEPT_DOMAIN=()
ACCEPT_IP=()
ALT_AUTO=

while [ $# -ge 1 ] ; do
  case "$1" in
    --domain) if [[ "$2" == -* || -z "$2"  ]]; then command_error $1 ; else ACCEPT_DOMAIN[${#ACCEPT_DOMAIN[*]}]=$2; shift 2; fi ;;
    --ip) if [[ "$2" == -* || -z "$2"  ]]; then command_error $1 ; else ACCEPT_IP[${#ACCEPT_IP[*]}]=$2; shift 2; fi ;;
    --altauto) ALT_AUTO=1; shift 1;;
    --email) if [[ "$2" == -* || -z "$2"  ]]; then command_error $1 ; else EMAIL="$2"; shift 2; fi ;;
    --pass) if [[ "$2" == -* || -z "$2"  ]]; then command_error $1 ; else PASS="$2"; shift 2; fi ;;
    --country) if [[ "$2" == -* || -z "$2" ]]; then command_error $1 ; else Country="$2"; shift 2; fi ;;
    --state) if [[ "$2" == -* || -z "$2"  ]]; then command_error $1 ; else State="$2"; shift 2; fi ;;
    --locality) if [[ "$2" == -* || -z "$2"  ]]; then command_error $1 ; else Locality="$2"; shift 2; fi ;;
    --organization) if [[ "$2" == -* || -z "$2"  ]]; then command_error $1 ; else Organization="$2"; shift 2; fi ;;
    --unit) if [[ "$2" == -* || -z "$2"  ]]; then command_error $1 ; else Unit="$2"; shift 2; fi ;;
    --commonname) if [[ "$2" == -* || -z "$2"  ]]; then command_error $1 ; else CommonName="$2"; shift 2; fi ;;
    --help) shift 1;;
    -h) shift 1;;
    *) echo "unknown parameter $1." ; Usage ; break;;
  esac    
done

if [[ ${#ACCEPT_DOMAIN[*]} == 0 && ${#ACCEPT_IP[*]} == 0 && -z "${ALT_AUTO}" ]]; then
  echo '请指定 --domain 或 --ip 或 --altauto 参数'
  exit 1
fi

if [[ ! -z ${ALT_AUTO} ]]; then
  ALT_NAME="IP:$(hostname -i)"
  ALT_NAME="${ALT_NAME},DNS:localhost,DNS:localhost.local"
  ALT_NAME="${ALT_NAME},IP:::1"
  ALT_NAME="${ALT_NAME},DNS:ip6-localhost,DNS:ip6-loopback"
  INTERFACES=`ifconfig | grep -Po '^[^\s:]+' | grep -v 'lo\|docker'`
  for interface in ${INTERFACES[@]};do
    ips=$(ip addr show "$interface" | awk -F '[/[:space:]]+' '$2 == "inet" { print $3 }')
    for ip in $ips; do
      ALT_NAME="${ALT_NAME},IP:$ip"
    done
  done
fi

for domain in ${ACCEPT_DOMAIN[@]}
do
  ALT_NAME=${ALT_NAME},DNS:${domain}
done

for ip in ${ACCEPT_IP[@]}
do
  ALT_NAME=${ALT_NAME},IP:${ip},
done

# 验证密码是否输入
if [ -z "${PASS}" ] ;then
  echo "请输入密码 --pass xxxx"
  exit 1
fi

# 验证Email是否输入
if [ -z "${EMAIL}" ] ;then
  echo "请输入邮件地址 --email xxxx@xxx.xxx"
  exit 1
fi


SUBJ="/C=${Country}/ST=${State}/L=${Locality}/O=${Organization}/OU=${Unit}/CN=${CommonName}/emailAddress=${EMAIL}"

# 生成CA证书及服务端秘钥
SERVER_PATH="./server"
mkdir -p ${SERVER_PATH}
openssl genrsa -aes256 -passout pass:${PASS} -out ${SERVER_PATH}/ca-key.pem 4096
openssl req -passin pass:${PASS} -new -x509 -days 365 -key ${SERVER_PATH}/ca-key.pem -sha256 -out ${SERVER_PATH}/ca.pem -subj ${SUBJ}

openssl genrsa -out ${SERVER_PATH}/server-key.pem 4096
openssl req -subj "/CN=${CommonName}" -sha256 -new -key ${SERVER_PATH}/server-key.pem -out ${SERVER_PATH}/server.csr
echo subjectAltName = ${ALT_NAME} >> ${SERVER_PATH}/extfile.cnf
echo extendedKeyUsage = serverAuth >> ${SERVER_PATH}/extfile.cnf
openssl x509 -passin pass:${PASS} -req -days 365 -sha256 -in ${SERVER_PATH}/server.csr -CA ${SERVER_PATH}/ca.pem -CAkey ${SERVER_PATH}/ca-key.pem -CAcreateserial -out ${SERVER_PATH}/server-cert.pem -extfile ${SERVER_PATH}/extfile.cnf

# 删除过程文件
rm -f ${SERVER_PATH}/server.csr ${SERVER_PATH}/extfile.cnf ./.srl

chmod -v 0400 ${SERVER_PATH}/ca-key.pem ${SERVER_PATH}/server-key.pem
chmod -v 0444 ${SERVER_PATH}/ca.pem ${SERVER_PATH}/server-cert.pem
