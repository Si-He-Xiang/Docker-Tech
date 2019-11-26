
#!/usr/bin/env bash


PASS=
USER=

while [ $# -ge 2 ] ; do
  case "$1" in
    --pass) PASS="$2"; shift 2;;
    --user) USER="$2"; shift 2;;
    *) echo "unknown parameter $1." ; exit 1 ; break;;
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
