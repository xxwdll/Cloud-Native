#### 参考文章
[安装 Kubernetes 集群](https://k8s.easydoc.net/doc/28366845/6GiNOzyZ/nd7yOvdY)

#### 学习时间 2023-02-01

### 初始化

所有节点都需要此操作
#### 准备 三台主机
|   节点  | ip  | 配置 | 操作系统 |
|  ----  | ----  | --- | --- |
| node1  | 10.23.238.216 | 2C 4G | centos8 |
| node2  | 10.23.46.92 | 2C 4G | centos8 |
| node3  | 10.23.203.186 | 2C 4G | centos8 |


#### hostname
```bash
#!/bin/bash
export node_name=$1
hostnamectl set-hostname $node_name
cat <<EOF >> /etc/hosts
192.168.44.97 node1
192.168.44.161 node2
192.168.44.85 node3
EOF
setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
```


#### 安装源
```bash
# 添加 k8s 安装源
cat <<EOF > kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
mv kubernetes.repo /etc/yum.repos.d/

# 添加 Docker 安装源
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```

#### 安装组件
```bash
yum erase podman buildah
dnf install https://download.docker.com/linux/centos/8/x86_64/stable/Packages/containerd.io-1.4.3-3.1.el8.x86_64.rpm
yum install -y kubelet-1.22.4 kubectl-1.22.4 kubeadm-1.22.4 docker-ce
```

#### 开机启动

```bash
systemctl enable kubelet
systemctl start kubelet
systemctl enable docker
systemctl start docker
```


#### docker 配置修改
```bash
# kubernetes 官方推荐 docker 等使用 systemd 作为 cgroupdriver，否则 kubelet 启动不了
cat <<EOF > daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": ["https://ud6340vz.mirror.aliyuncs.com"]
}
EOF
mv daemon.json /etc/docker/

# 重启生效
systemctl daemon-reload
systemctl restart docker
```


### 初始化master

```bash
# 初始化集群控制台 Control plane
# 失败了可以用 kubeadm reset 重置
kubeadm init --image-repository=registry.aliyuncs.com/google_containers

# 记得把 kubeadm join xxx 保存起来
kubeadm join 10.23.238.216:6443 --token jt76zw.gu9wlofx4rbnks9b \
	--discovery-token-ca-cert-hash sha256:72253f4d98cdcde76a1fed8a3a8db4d41cc995dcc9c017834511d0df3bc9df66
# 忘记了重新获取：kubeadm token create --print-join-command

# 复制授权文件，以便 kubectl 可以有权限访问集群
# 如果你其他节点需要访问集群，需要从主节点复制这个文件过去其他节点
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

安装网络插件
```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

### 安装网络插件

#### 指定cidr
由于在kubeadm初始化没有加 --pod-network-cidr参数
[参考方法](https://juejin.cn/post/6867846255884632078)
```bash
1.
kube edit cm kubeadm-config -n kube-system
在 networking 下 增加 podSubnet: 10.244.0.0/16

2.
sudo vim /etc/kubernetes/manifests/kube-controller-manager.yaml 
修改 controller-manager 静态 pod 的启动参数，增加 --allocate-node-cidrs=true --cluster-cidr=10.244.0.0/16

3.
kubectl cluster-info dump | grep -m 1 cluster-cidr
```

#### 安装flannel
```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

#### check
完成!
```bash
[root@node1 kubelet.service.d]# kubectl get pods -A
NAMESPACE      NAME                            READY   STATUS    RESTARTS   AGE
kube-flannel   kube-flannel-ds-dnz26           1/1     Running   0          4m39s
kube-flannel   kube-flannel-ds-j7wsz           1/1     Running   0          4m39s
kube-flannel   kube-flannel-ds-v6zw2           1/1     Running   0          4m39s
kube-system    coredns-7f6cbbb7b8-8jzvj        1/1     Running   0          38m
kube-system    coredns-7f6cbbb7b8-xl5rx        1/1     Running   0          38m
kube-system    etcd-node1                      1/1     Running   0          38m
kube-system    kube-apiserver-node1            1/1     Running   0          38m
kube-system    kube-controller-manager-node1   1/1     Running   0          5m23s
kube-system    kube-proxy-29dcq                1/1     Running   0          35m
kube-system    kube-proxy-t65mx                1/1     Running   0          38m
kube-system    kube-proxy-vkcc2                1/1     Running   0          35m
kube-system    kube-scheduler-node1            1/1     Running   0          38m
[root@node1 kubelet.service.d]#
[root@node1 kubelet.service.d]# kubectl get nodes -A
NAME    STATUS   ROLES                  AGE   VERSION
node1   Ready    control-plane,master   38m   v1.22.4
node2   Ready    <none>                 35m   v1.22.4
node3   Ready    <none>                 35m   v1.22.4
[root@node1 kubelet.service.d]#
[root@node1 kubelet.service.d]#
```