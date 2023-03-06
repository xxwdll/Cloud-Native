#!/bin/bash
export node_name=$1
export conf_name=$2


hostnamectl set-hostname $node_name
# cat <<EOF >> /etc/hosts
# 192.168.44.97 node1
# 192.168.44.161 node2
# 192.168.44.85 node3
# EOF

cat $conf_name >> /etc/hosts

setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

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

yum install -y yum-utils device-mapper-persistent-data lvm2 nfs-utils
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

yum erase podman buildah -y
dnf install https://download.docker.com/linux/centos/8/x86_64/stable/Packages/containerd.io-1.4.3-3.1.el8.x86_64.rpm -y
yum install -y kubelet-1.22.4 kubectl-1.22.4 kubeadm-1.22.4 docker-ce

systemctl enable kubelet
systemctl start kubelet
systemctl enable docker
systemctl start docker

cat <<EOF > daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": ["https://ud6340vz.mirror.aliyuncs.com"]
}
EOF
mv daemon.json /etc/docker/

systemctl daemon-reload
systemctl restart docker

# --cluster-cidr=10.244.0.0/16 
#kubeadm init --image-repository=registry.aliyuncs.com/google_containers --pod-network-cidr=10.244.0.0/16