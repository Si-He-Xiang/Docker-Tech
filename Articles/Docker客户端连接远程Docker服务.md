Docker桌面版安装包括了Docker Client和Docker Engine。但Docker Engine不但污染了我纯洁的小本本还占据了几十个G的硬盘空间，真是万恶。所以我删除了桌面版的Docker，仅在笔记本上安装客户端，通过客户端连接云主机的Docker Engine。下面我来整理一下过程。

# 安装Docker客户端
  在安装Docker的时候，我们并不需要安装官网提供的标准安装包，因为那包括了`Docker Engine`和`Docker Client`。

所以我们需要安装的是`docker-toolbox`。MacOS可以通过`brew search docker-toolbox`找到，其他系统可以通过github下载[https://github.com/docker/toolbox/releases](https://github.com/docker/toolbox/releases)

开始安装 Docker 客户端。
```shell
$ brew cask install docker-toolbox     
```
> docker-toolbox包含以下几部分内容
> * docker-cli : 客户端命令行,目前的版本是19.03.1
> * docker-machine : 可以在本机启动用于Docker Engine虚拟机并管理他们
> * docker-compose : docker提供的编排工具，支持compose文件，这个并不常用。
> * Kitematic : Docker的客户端GUI，官方已经废弃了。
> * Boot2Docker ISO : 用于创建Docker Engine虚拟机的镜像。由于包中的这个版本并不是最新的，所以创建虚拟机的时候可能会需要重新下载。
> * VirtualBox : 虚拟机

# 连接远程 Docker Engine
  本文先不介绍Docker服务器如何部署。我们假定服务器已经部署完毕，从开启远程连接端口开始介绍。
## 服务器环境
* Ubuntu 18.04.3 LTS bionic （AWS免费EC2服务器）
* Docker Version
  > Server: Docker Engine - Community  
  > &nbsp;&nbsp;Engine:  
  > &nbsp;&nbsp;&nbsp;&nbsp;Version:19.03.5  

## 开启远程连接端口
Docker的Client和Engine之间的通讯有一下几种方式
> * Unix Socket 
>   这是类unix系统进程间通讯的一种方式，当Client操作本机的Engine是就是使用这种方式。缺省的socket文件是`unix:///var/run/docker.sock`
> 
> * Systemd socket activation : 
>   这是`systemd`提供的一种为了服务并行启动设计的socket，缺省值为`fd://`
>   对这个技术感兴趣的小伙伴可以进一步了解一下。
>   [http://0pointer.de/blog/projects/socket-activation.html](http://0pointer.de/blog/projects/socket-activation.html)
>   这还有一篇中文的文章讲解的不错 
>    [https://segmentfault.com/a/1190000017132823?utm_source=tag-newest](https://segmentfault.com/a/1190000017132823?utm_source=tag-newest)
> 
> * TCP :
>   上面两种都是只能连接本地Engine，需要连接远程Engine，必须在服务端开始TCP连接。此连接为不安全连接，数据通过明文进行传输。缺省端口`2375`。
> 
> * TCP_TLS :
>   在TCP的基础之上加上了SSL的安全证书，以保证连接安全。缺省端口`2376`。

### 不加密的TCP连接
我们先开启一个简单的TCP连接测试一下Docker Engine
登录远程服务器
```shell
$ ssh <server-name-in-ssh-config>
```
我们的操作涉及两个配置文件
* `<?>/systemd/system/docker.service`  
  docker的系统服务脚本文件。此文件是通过`systemctl`命令启动或停止服务时执行的脚本。
  在不同系统中，此文件的路径不同。我们可以通过命令来查看
  ```shell
  $ sudo systemctl status docker|grep Loaded|grep -Po '(?<=Loaded: loaded \()[^;]*'
  /lib/systemd/system/docker.service
  ```

* `/etc/docker/daemon.json`  
  `dockerd`命令对应的配置文件。`dockerd`命令是Docker Engine的启动命令。启动时的参数可以通过命令行参数提供，也可以通过此配置文件提供。具体信息可以参考官方文档
  [https://docs.docker.com/engine/reference/commandline/dockerd/](https://docs.docker.com/engine/reference/commandline/dockerd/)

先打开`docker.service`，并找到Engine的启动命令
```shell
$ sudo cat $(systemctl status docker|grep Loaded|grep -Po '(?<=Loaded: loaded \()[^;]*')|grep dockerd
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
```
可以看到这个参数`-H fd://`，意思是启用`socket activation`作为客户端接口。
我们要把它删掉。因为官方的文档中介绍说:
> Note: You cannot set options in daemon.json that have already been set on daemon startup as a flag. On systems that use systemd to start the Docker daemon, -H is already set, so you cannot use the hosts key in daemon.json to add listening addresses. See https://docs.docker.com/engine/admin/systemd/#custom-docker-daemon-options for how to accomplish this task with a systemd drop-in file.
> 灵魂翻译：在命令行设置的参数，不能在`daemon.json`中进行设置。嗯，就是这样。

```shell
$ # 先备份docker.service
$ SERVICE_FILE=$(systemctl status docker|grep Loaded|grep -Po '(?<=Loaded: loaded \()[^;]*') \
  && sudo cp ${SERVICE_FILE} ${SERVICE_FILE}.bak
$
$ # 删除dockerd的 -H参数
$ SERVICE_FILE=$(systemctl status docker|grep Loaded|grep -Po '(?<=Loaded: loaded \()[^;]*') \
  && sudo sed -i -e 's/ -H fd:\/\/ / /g' ${SERVICE_FILE}
$
$ # 再次查看验证
$ sudo cat $(systemctl status docker|grep Loaded|grep -Po '(?<=Loaded: loaded \()[^;]*')|grep dockerd
ExecStart=/usr/bin/dockerd --containerd=/run/containerd/containerd.sock
$ # OK
```
添加或修改`daemon.json`
如果没有这个文件可以直接建立
```shell
$ sudo ls /etc/docker/daemon.json
ls: cannot access '/etc/docker/daemon.json': No such file or directory
$
$ sudo sh -c 'echo "{
  \"hosts\":[
    \"fd://\",
    \"tcp://0.0.0.0:2375\"
  ]
}">/etc/docker/daemon.json'
```

如果文件已经存在
则需添加如下内容
```javascript
  "hosts":[
    "fd://",
    "tcp://0.0.0.0:2375"
  ]
```
现在重启 docker服务
```shell
$ sudo systemctl daemon-reload
$ sudo systemctl restart docker
$ sudo systemctl status docker
● docker.service - Docker Application Container Engine
   Loaded: loaded (/lib/systemd/system/docker.service; enabled; vendor preset: enabled)
   Active: active (running) since Wed 2019-11-27 07:48:40 UTC; 31s ago
     Docs: https://docs.docker.com
 Main PID: 19750 (dockerd)
    Tasks: 8
   CGroup: /system.slice/docker.service
           └─19750 /usr/bin/dockerd --containerd=/run/containerd/containerd.sock
```

重启成功，查看端口`2375`是否开放。
```shell
$ ss -l |grep -Po '\s[^\s]*2375\s'
*:2375
$ # OK
```
客户端连接
```shell
$ docker -H tcp://<服务器IP>:2375 version 
Client: Docker Engine - Community
 Version:           19.03.1
 API version:       1.40
 Go version:        go1.12.5
 Git commit:        74b1e89
 Built:             Thu Jul 25 21:18:17 2019
 OS/Arch:           darwin/amd64
 Experimental:      false

Server: Docker Engine - Community
 Engine:
  Version:          19.03.5
  API version:      1.40 (minimum version 1.12)
  Go version:       go1.12.12
  Git commit:       633a0ea838
  Built:            Wed Nov 13 07:28:22 2019
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          1.2.10
  GitCommit:        b34a5c8af56e510852c35414db4c1f4fa6172339
 runc:
  Version:          1.0.0-rc8+dev
  GitCommit:        3e425f80a8c931f88e6d94a8c831b9d5aa481657
 docker-init:
  Version:          0.18.0
  GitCommit:        fec3683
```
可以看到客户端版本`19.03.01`，服务器端版本`19.03.5`。连接OK。

> 如果连接不上，经常是防火墙的问题
> 由于Docker Engine使用iptables来作为容器网络的转发。所以不能直接禁止iptables，需要添加相关的`INPUT`策略。
> 例如：
> `iptables -A INPUT -p tcp --dport 2375 -j ACCEPT`
> 具体如何添加能够生效，则需要根据服务器iptables的具体情况进行调整。
> 例如：我在`vultr.com`的服务器所有的`INPUT chain`都转向了`IN_public_allow chain`，上面那个命令添加后不会生效。需要在修改命令为`iptables -A IN_public_allow -p tcp --dport 2375 -j ACCEPT`

### 安全TCP连接（TCP+TLS）
上一节我们已经连接了远程的Docker服务。但由于传输没有加密，同时也没有身份认证，任何人都可以连接到服务器。那么我们需要在此基础上进行安全证书的生成和配置。
#### 创建CA和证书
过程具体参见Docker官网教程[Protect the Docker daemon socket]([https://docs.docker.com/engine/security/https/](https://docs.docker.com/engine/security/https/)
)

我对这个过程编写了两个shell脚本可以简化这个过程
[gen-server.sh](https://raw.githubusercontent.com/Si-He-Xiang/Docker-Tech/master/Docker%E7%A7%91%E6%99%AE/scripts/%E7%94%9F%E6%88%90%E8%BF%9E%E6%8E%A5%E8%AF%81%E4%B9%A6/gen-server.sh) : 生成服务器端的CA和证书
[gen-user.sh](https://raw.githubusercontent.com/Si-He-Xiang/Docker-Tech/master/Docker%E7%A7%91%E6%99%AE/scripts/%E7%94%9F%E6%88%90%E8%BF%9E%E6%8E%A5%E8%AF%81%E4%B9%A6/gen-user.sh) : 生成客户端使用的证书

```shell
$ # ------服务端操作------
$ # 创建临时目录
$ mkdir -p ~/.ssh/tls
$ cd ~/.ssh/tls
$ 
$ # 下载脚本
$ curl https://raw.githubusercontent.com/Si-He-Xiang/Docker-Tech/master/Docker%E7%A7%91%E6%99%AE/scripts/%E7%94%9F%E6%88%90%E8%BF%9E%E6%8E%A5%E8%AF%81%E4%B9%A6/gen-server.sh > gen-server.sh
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  2032  100  2032    0     0   5822      0 --:--:-- --:--:-- --:--:--  5805
$ curl https://raw.githubusercontent.com/Si-He-Xiang/Docker-Tech/master/Docker%E7%A7%91%E6%99%AE/scripts/%E7%94%9F%E6%88%90%E8%BF%9E%E6%8E%A5%E8%AF%81%E4%B9%A6/gen-user.sh >  gen-user.sh
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  2160  100  2160    0     0    539      0  0:00:04  0:00:04 --:--:--   539
$ 
$ chmod +x gen-server.sh gen-user.sh
$
$ # 生成服务器端证书
$ # gen-server.sh至少需要三个参数 
$ # --pass 表示更证书Key的密钥
$ # --email 邮箱地址
$ # --domain 服务器的域名 或 使用 --ip 制定服务器IP
$ ./gen-server.sh --pass 111111 --altauto --domain <服务器域名> --email <邮件地址>
Generating RSA private key, 4096 bit long modulus
...................................................................++
.............++
e is 65537 (0x10001)
Generating RSA private key, 4096 bit long modulus
.............................++
............................................................++
e is 65537 (0x10001)
Signature ok
subject=/CN=si_he_xiang.github.com
Getting CA Private Key
mode of "./server/ca-key.pem" changed from 0664 (rw-rw-r--) to 0400 (r--------)
mode of "./server/server-key.pem" changed from 0664 (rw-rw-r--) to 0400 (r--------)
mode of "./server/ca.pem" changed from 0664 (rw-rw-r--) to 0444 (r--r--r--)
mode of "./server/server-cert.pem" changed from 0664 (rw-rw-r--) to 0444 (r--r--r--)
$ 
$ # 此命令在当前目录下创建了子目录"server"
$ ls -l ./server
总用量 16
-r-------- 1 op op 3326 11月 28 16:20 ca-key.pem
-r--r--r-- 1 op op 2143 11月 28 16:20 ca.pem
-r--r--r-- 1 op op 2074 11月 28 16:20 server-cert.pem
-r-------- 1 op op 3243 11月 28 16:20 server-key.pem
$ 
$ # 将这4个文件复制到docker配置目录
$ sudo mkdir -p /etc/docker/tls
$ sudo cp ./server/* /etc/docker/tls/
$
$ # 生成客户端证书
$ # 密码需要和上面的CAKey密码一致
$ # -t 参数可以将生成的客户端证书打包，以方面下载。（可以通过"--tar filename"指定打包文件名）
$ ./gen-user.sh --pass 111111 --user tester -t
$ ls -l tester*
-rw-rw-r-- 1 op op 4932 11月 28 16:27 tester-cert.tar.gz
$
$ # 证书生成完毕
```
现在证书已经生成完了。我们需要让Docker Engine使用服务器端证书来验证链接。
打开配置文件`vi /etc/docker/daemon.json`, 根据之前的操作其内容应该是这样的：
```json
{
  "hosts":[
    "fd://",
    "tcp://0.0.0.0:2375"
  ]
}
```
我们把它改成这个样子：
```json
{
  "hosts":[
    "fd://",
    "tcp://0.0.0.0:2376"
  ],
  "tlsverify":true,
  "tlscacert":"/etc/docker/tls/ca.pem",
  "tlscert":"/etc/docker/tls/server-cert.pem",
  "tlskey":"/etc/docker/tls/server-key.pem"
}
```
> 端口由`2375`改为`2376`，`2376`是Docker Engine默认的TLS端口。
重启服务
```shell
$ sudo systemctl restart docker 
```
现在服务器端配置完成。别忘了在防火墙打开`2376`端口。

#### 配置客户端
下面我们进入客户端操作。上一步我们在服务器上生成了客户端需要使用的证书，我们下载到客户端。
```shell
$ # 下载证书
$ mkdir -p ~/.ssh/tls
$ scp <server-name-in-ssh-config>:~/.ssh/tls/tester-cert.tar.gz ~/.ssh/tls
$ mkdir -p ~/.ssh/tls/docker
$ cd  ~/.ssh/tls/docker
$ tar -xzvf ~/.ssh/tls/tester-cert.tar.gz
$ cd tester
$ ls -l
total 24
-r--r--r--  1 shixiao  staff  2143 11 28 16:27 ca.pem
-r--r--r--  1 shixiao  staff  1883 11 28 16:27 cert.pem
-r--------  1 shixiao  staff  3247 11 28 16:27 key.pem
$ pwd
<HOME>/.ssh/tls/docker/tester
```
下面我们通过命令连接服务器
```shell
$ docker -H tcp://<服务器域名>:2376 \
  --tlsverify=1 \
  --tlscacert=${HOME}/.ssh/tls/docker/tester/ca.pem \
  --tlscert=${HOME}/.ssh/tls/docker/tester/cert.pem \
  --tlskey=${HOME}/.ssh/tls/docker/tester/key.pem \
  version
Client: Docker Engine - Community
 Version:           19.03.1
 API version:       1.40
 Go version:        go1.12.5
 Git commit:        74b1e89
 Built:             Thu Jul 25 21:18:17 2019
 OS/Arch:           darwin/amd64
 Experimental:      false

Server: Docker Engine - Community
 Engine:
  Version:          19.03.5
  API version:      1.40 (minimum version 1.12)
  Go version:       go1.12.12
  Git commit:       633a0ea838
  Built:            Wed Nov 13 07:28:22 2019
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          1.2.10
  GitCommit:        b34a5c8af56e510852c35414db4c1f4fa6172339
 runc:
  Version:          1.0.0-rc8+dev
  GitCommit:        3e425f80a8c931f88e6d94a8c831b9d5aa481657
 docker-init:
  Version:          0.18.0
  GitCommit:        fec3683
$
$ # OK!连接成功
```
#### 扩展一下客户端功能
到上一节为止我们已经成功完成了所有连接必须的内容。
有时候我们的客户端会需要在几个不同的环境中进行切换，为了操作方便，我建立了几个命令行的`alias`。
首先，我们有几个约定：
* 所有服务器的配置和证书都放到`~/.ssh/tls/docker`目录下的独立子目录中。
* `~/.ssh/tls/docker`目录下的子目录名即服务器配置名称
* 服务器配置子目录中必须包含4个文件
  * ca.pem : CA证书
  * cert.pem : 客户端证书
  * key.pem : 客户端证书Key
  * host : 服务点连接地址及端口配置

那么，现在我们要为之前创建的目录`~/.ssh/tls/docker/tester`添加`host`文件
```shell
$ echo "tcp://<服务器域名>:2376" > ~/.ssh/tls/docker/tester/host
```
现在一个遵循约定的docker服务器配置目录已经有了，下面我们创建`alias`。
```shell
$ # 下载.alias_docker.sh
$ curl https://raw.githubusercontent.com/Si-He-Xiang/Docker-Tech/master/Docker%E7%A7%91%E6%99%AE/scripts/.alias_docker.sh >.alias_docker.sh
```

>[`.alias_docker.sh`](https://raw.githubusercontent.com/Si-He-Xiang/Docker-Tech/master/Docker%E7%A7%91%E6%99%AE/scripts/.alias_docker.sh)文件中包含4个扩展命令。
> * docker-show : 查看当前激活的docker连接
> * docker-clear : 清除docker连接
> * docker-switch : 激活或切换到指定的docker连接
> * docker-list ：查看可用的docker连接（即符合上述约定的目录名称）

下载`.alias_docker.sh`文件并将其加入启动脚本，然后尝试一下这几个命令。
```shell
$ docker-list
tester
$ 
$ docker-show
DOCKER_HOST= 
DOCKER_TLS_VERIFY= 
DOCKER_CERT_PATH= 
$ 
$ docker-switch tester
DOCKER_HOST=tcp://<服务器域名>:2376 
DOCKER_TLS_VERIFY=1 
DOCKER_CERT_PATH=<HOME>/.ssh/tls/docker/tester 
$ 
$ docker version
.......
.......
$ # OK! 完结撒花
```
