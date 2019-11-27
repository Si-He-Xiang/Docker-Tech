#!/usr/bin/env bash

Usage(){
    cat <<EOF

Usage: $0 <--pass> <--user> [-t | --tar <filename>]

生成Docker使用的客户端证书

Requires:
  --pass string             CA的签名密码
  --user string             客户端的用户名

Options:
  -t,--tar filename         将生成的证书打包，包名缺省"${USER}-cert.tar.gz"

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


PASS=
USER=
TAR_NAME=
TAR_ENABLE=

while [ $# -ge 1 ] ; do
  case "$1" in
    --pass) if [[ "$2" == -* || -z "$2"  ]]; then command_error $1 ; else PASS="$2"; shift 2; fi ;;
    --user) if [[ "$2" == -* || -z "$2"  ]]; then command_error $1 ; else USER="$2"; shift 2; fi ;;
    --tar) if [[ "$2" == -* || -z "$2"  ]]; then command_error $1 ; else TAR_ENABLE=1; TAR_NAME="$2"; shift 2; fi ;;
    -t) TAR_ENABLE=1; shift 1;;
    --help) shift 1;;
    -h) shift 1;;
    *) echo "unknown parameter $1." ; Usage ; break;;
  esac    
done


# 验证密码是否输入
if [ -z "${PASS}" ] ;then
  echo "请输入密码 --pass xxxx"
  exit 1
fi

# 验证用户名是否输入
if [ -z "${USER}" ] ;then
  echo "请输入用户名 --user xxxx"
  exit 1
fi

SERVER_PATH="./server"
# 生成客户端秘钥
USER_PATH="./${USER}"
mkdir -p ${USER_PATH}
openssl genrsa -out ${USER_PATH}/key.pem 4096
openssl req -subj "/CN=${USER}" -new -key ${USER_PATH}/key.pem -out ${USER_PATH}/client.csr
echo extendedKeyUsage = clientAuth > ${USER_PATH}/extfile-client.cnf
openssl x509 -passin pass:${PASS} -req -days 365 -sha256 -in ${USER_PATH}/client.csr -CA ${SERVER_PATH}/ca.pem -CAkey ${SERVER_PATH}/ca-key.pem -CAcreateserial -out ${USER_PATH}/cert.pem -extfile ${USER_PATH}/extfile-client.cnf

# 删除过程文件
rm ${USER_PATH}/client.csr ${USER_PATH}/extfile-client.cnf

chmod -v 0400 ${USER_PATH}/key.pem
chmod -v 0444 ${USER_PATH}/cert.pem

# 复制根证书
cp -f ${SERVER_PATH}/ca.pem ${USER_PATH}/

# 打包
if [[ ! -z "${TAR_ENABLE}" ]]; then
  if [[ -z "${TAR_NAME}" ]]; then
    TAR_NAME=${USER}-cert.tar.gz
  fi
  tar -czvf ${TAR_NAME} ./${USER}/*  
  rm -rf ./${USER}
fi
