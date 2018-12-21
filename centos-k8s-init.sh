#!/bin/sh

#  centos-k8s-init.sh
#  
#
#  Created by csc on 2018/12/21.
#  

yum install -y wget curl conntrack-tools vim net-tools socat ntp kmod ceph-common

echo 'sync time'
systemctl start ntpd
systemctl enable ntpd

echo 'disable selinux'
setenforce 0
sed -i 's/=enforcing/=disabled/g' /etc/selinux/config
yum install gcc
yum install kernel-devel

#systemctl stop firewalld
#systemctl disable firewalld

cp k8s.conf /etc/sysctl.d/k8s.conf
modprobe br_netfilter
sysctl -p /etc/sysctl.d/k8s.conf

mv CentOS7-Base-163.repo /etc/yum.repos.d/CentOS-Base.repo

cp kubernetes.repo /etc/yum.repos.d/kubernetes.repo
yum makecache fast
yum install -y kubelet kubeadm kubectl

# 临时禁用selinux
# 永久关闭 修改/etc/sysconfig/selinux文件设置
sed -i 's/SELINUX=permissive/SELINUX=disabled/' /etc/sysconfig/selinux
setenforce 0

# 临时关闭swap
# 永久关闭 注释/etc/fstab文件里swap相关的行
swapoff -a
sed -i '/swap/s/^/#/' /etc/fstab

iptables -P FORWARD ACCEPT

sysctl --system
modprobe ip_vs
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh
modprobe nf_conntrack_ipv4
lsmod | grep ip_vs

docker pull registry.cn-shenzhen.aliyuncs.com/cp_m/flannel:v0.10.0-amd64
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/kubernetes-dashboard-amd64:v1.10.0
sh tag-sh.sh

cp kubelet /etc/sysconfig/

systemctl enable kubelet && systemctl restart kubelet

kubeadm init --config kubeadm-master.config

kubeadm reset -f

kubeadm init --kubernetes-version=v1.13.1   --pod-network-cidr=10.244.0.0/16   --apiserver-advertise-address=172.17.8.101 --token=cbc0fd.0w7gve4y3ze9ntqj --token-ttl=0

mkdir -p $HOME/.kube
cp /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f kube-flannel.yml

kubectl taint nodes Linux node-role.kubernetes.io/master-

systemctl restart kubelet
