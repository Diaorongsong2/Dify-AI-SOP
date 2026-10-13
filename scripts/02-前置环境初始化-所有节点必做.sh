#!/bin/bash
# Dify-AI-SOP — 前置环境初始化(所有节点必做)
# 由 SOP 中对应章节的命令整理而成（含执行输出示例）

# --------------------------------------------------------------------
# 操作系统选型与替换
# --------------------------------------------------------------------
# 执行以下命令，输出 Rocky Linux release 9.x 即为正常
cat /etc/rocky-release

# --------------------------------------------------------------------
# 基础依赖包安装
# --------------------------------------------------------------------
dnf install -y wget vim net-tools gcc gcc-c++ make git curl jq

# --------------------------------------------------------------------
# Docker 与 Docker Compose v2 安装
# --------------------------------------------------------------------
# 1. 备份并替换 Rocky 9 系统源为阿里云镜像
mkdir -p /etc/yum.repos.d/bak
mv /etc/yum.repos.d/Rocky-*.repo /etc/yum.repos.d/bak/
curl -o /etc/yum.repos.d/Rocky-BaseOS.repo https://mirrors.aliyun.com/repo/Rocky-9-BaseOS.repo
curl -o /etc/yum.repos.d/Rocky-AppStream.repo https://mirrors.aliyun.com/repo/Rocky-9-AppStream.repo
curl -o /etc/yum.repos.d/Rocky-Extras.repo https://mirrors.aliyun.com/repo/Rocky-9-Extras.repo
dnf clean all && dnf makecache

# 2. 安装源管理工具
dnf install -y yum-utils device-mapper-persistent-data lvm2

# 3. 添加阿里云 Docker CE 镜像源，修正版本变量适配 Rocky 9
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
sed -i 's/$releasever/9/g' /etc/yum.repos.d/docker-ce.repo

# --------------------------------------------------------------------
# Docker 与 Docker Compose v2 安装
# --------------------------------------------------------------------
dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# --------------------------------------------------------------------
# Docker 与 Docker Compose v2 安装
# --------------------------------------------------------------------
# 1. 创建 Docker 配置目录，配置国内镜像加速（以华为云 SWR 加速为例）
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [
    "https://382d8a78866945cdafcd976ca3fb55bd.mirror.swr.myhuaweicloud.com",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "mtu": 1400
}
EOF

# 2. 启动服务并设置开机自启
systemctl daemon-reload
systemctl start docker
systemctl enable docker

# --------------------------------------------------------------------
# Docker 与 Docker Compose v2 安装
# --------------------------------------------------------------------
docker --version
docker compose version

# --------------------------------------------------------------------
# 系统基础配置
# --------------------------------------------------------------------
# 关闭防火墙（生产环境可按需开放端口）
systemctl stop firewalld
systemctl disable firewalld

# 关闭SELinux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

# 时间同步与时区设置
timedatectl set-timezone Asia/Shanghai

# 配置公共 DNS，避免域名解析失败
echo -e "nameserver 223.5.5.5\nnameserver 223.6.6.6\nnameserver 114.114.114.114" > /etc/resolv.conf
