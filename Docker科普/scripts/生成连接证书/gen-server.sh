#!/usr/bin/env bash

PASS=
Country=CN
State=
Locality=
Organization=
Unit=
CommonName=
EMAIL=
HOST=

while [ $# -ge 2 ] ; do
  case "$1" in
    --country) Country="$2"; shift 2;;
    --state) State="$2"; shift 2;;
    --locality) Locality="$2"; shift 2;;
    --organization) Organization="$2"; shift 2;;
    --unit) State="$2"; shift 2;;
    --common-name) CommonName="$2"; shift 2;;
    --email) EMAIL="$2"; shift 2;;
    --pass) PASS="$2"; shift 2;;
    --host) HOST="$2"; shift 2;;
    *) echo "unknown parameter $1." ; exit 1 ; break;;
  esac    
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

# 验证主机域名是否输入
if [ -z "${HOST}" ] ;then
  HOST="${CommonName}"
fi
if [ -z "${HOST}" ] ;then
  echo "请输入主机名称 --host xxxx.xxx.xxx"
  exit 1
fi

SUBJ="/C=${Country}/ST=${State}/L=${Locality}/O=${Organization}/OU=${Unit}/CN=${CommonName}/emailAddress=${EMAIL}"

# 生成CA证书及服务端秘钥
SERVER_PATH="./server"
mkdir -p ${SERVER_PATH}
openssl genrsa -aes256 -passout pass:${PASS} -out ${SERVER_PATH}/ca-key.pem 4096
openssl req -passin pass:${PASS} -new -x509 -days 365 -key ${SERVER_PATH}/ca-key.pem -sha256 -out ${SERVER_PATH}/ca.pem -subj ${SUBJ}

openssl genrsa -out ${SERVER_PATH}/server-key.pem 4096
openssl req -subj "/CN=${HOST}" -sha256 -new -key ${SERVER_PATH}/server-key.pem -out ${SERVER_PATH}/server.csr
echo subjectAltName = DNS:${HOST},IP:127.0.0.1 >> ${SERVER_PATH}/extfile.cnf
echo extendedKeyUsage = serverAuth >> ${SERVER_PATH}/extfile.cnf
openssl x509 -passin pass:${PASS} -req -days 365 -sha256 -in ${SERVER_PATH}/server.csr -CA ${SERVER_PATH}/ca.pem -CAkey ${SERVER_PATH}/ca-key.pem -CAcreateserial -out ${SERVER_PATH}/server-cert.pem -extfile ${SERVER_PATH}/extfile.cnf

# 删除过程文件
rm ${SERVER_PATH}/server.csr ${SERVER_PATH}/extfile.cnf

chmod -v 0400 ${SERVER_PATH}/ca-key.pem ${SERVER_PATH}/server-key.pem
chmod -v 0444 ${SERVER_PATH}/ca.pem ${SERVER_PATH}/server-cert.pem
