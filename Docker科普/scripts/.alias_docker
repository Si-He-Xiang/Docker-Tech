# 查看当前激活的docker连接
alias docker-show='echo -e "DOCKER_HOST=${DOCKER_HOST} \nDOCKER_TLS_VERIFY=${DOCKER_TLS_VERIFY} \nDOCKER_CERT_PATH=${DOCKER_CERT_PATH} \n"'

# 清除docker连接
alias docker-clear='export DOCKER_HOST= DOCKER_TLS_VERIFY= DOCKER_CERT_PATH=;docker-show'

# 激活docker连接
alias docker-switch='function docker-switch(){ BASE_PATH=~/.ssh/tls/docker/$1;export DOCKER_HOST=$(cat ${BASE_PATH}/host) DOCKER_TLS_VERIFY=1 DOCKER_CERT_PATH=${BASE_PATH}; docker-show; };docker-switch'

# 查看可用的docker连接
alias docker-list='function docker-list(){ BASE_PATH=~/.ssh/tls/docker; 
for file in ${BASE_PATH}/*; 
do
  if [[ -f "${file}/host" && -f "${file}/ca.pem" && -f "${file}/cert.pem" && -f "${file}/key.pem" ]]; then
    echo ${file##*/}
  fi
done
};docker-list'
