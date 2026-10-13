#!/bin/bash
# Dify-AI-SOP — 方案二-K8s + Helm 生产集群部署
# 由 SOP 中对应章节的命令整理而成（含执行输出示例）

# --------------------------------------------------------------------
# 前置准备
# --------------------------------------------------------------------
# 验证节点状态
kubectl get nodes
# 验证核心组件状态
kubectl get pods -n kube-system

# --------------------------------------------------------------------
# 镜像预处理(解决官方镜像拉取失败)
# --------------------------------------------------------------------
# 1. 定义变量
DIFY_VERSION=1.16.0
HARBOR_ADDR=harbor.yourcompany.com/dify  # 替换为实际Harbor地址

# 2. 批量拉取官方镜像
docker pull langgenius/dify-api:${DIFY_VERSION}
docker pull langgenius/dify-web:${DIFY_VERSION}
docker pull langgenius/dify-agent-backend:${DIFY_VERSION}
docker pull langgenius/dify-sandbox:0.2.15
docker pull langgenius/dify-agent-local-sandbox:${DIFY_VERSION}
docker pull langgenius/dify-plugin-daemon:0.6.3-local
docker pull postgres:15-alpine
docker pull redis:6-alpine
docker pull semitechnologies/weaviate:1.27.0
docker pull nginx:1.27.0
docker pull ubuntu/squid:latest

# 3. 批量打标签
docker tag langgenius/dify-api:${DIFY_VERSION} ${HARBOR_ADDR}/dify-api:${DIFY_VERSION}
docker tag langgenius/dify-web:${DIFY_VERSION} ${HARBOR_ADDR}/dify-web:${DIFY_VERSION}
docker tag langgenius/dify-agent-backend:${DIFY_VERSION} ${HARBOR_ADDR}/dify-agent-backend:${DIFY_VERSION}
docker tag langgenius/dify-sandbox:0.2.15 ${HARBOR_ADDR}/dify-sandbox:0.2.15
docker tag langgenius/dify-agent-local-sandbox:${DIFY_VERSION} ${HARBOR_ADDR}/dify-agent-local-sandbox:${DIFY_VERSION}
docker tag langgenius/dify-plugin-daemon:0.6.3-local ${HARBOR_ADDR}/dify-plugin-daemon:0.6.3-local
docker tag postgres:15-alpine ${HARBOR_ADDR}/postgres:15-alpine
docker tag redis:6-alpine ${HARBOR_ADDR}/redis:6-alpine
docker tag semitechnologies/weaviate:1.27.0 ${HARBOR_ADDR}/weaviate:1.27.0
docker tag nginx:1.27.0 ${HARBOR_ADDR}/nginx:1.27.0
docker tag ubuntu/squid:latest ${HARBOR_ADDR}/ubuntu-squid:latest

# 4. 登录Harbor并批量推送
docker login ${HARBOR_ADDR} -u 管理员账号 -p 密码
docker push ${HARBOR_ADDR}/dify-api:${DIFY_VERSION}
docker push ${HARBOR_ADDR}/dify-web:${DIFY_VERSION}
# 依次推送所有打标后的镜像

# --------------------------------------------------------------------
# 镜像预处理(解决官方镜像拉取失败)
# --------------------------------------------------------------------
# 创建业务命名空间
kubectl create namespace dify

# 创建镜像拉取Secret
kubectl create secret docker-registry harbor-pull-secret \
  --docker-server=harbor.yourcompany.com \
  --docker-username=拉取账号 \
  --docker-password=密码 \
  -n dify

# --------------------------------------------------------------------
# PV/PVC 持久化存储配置
# --------------------------------------------------------------------
# 先查询集群可用存储类
kubectl get storageclass

# --------------------------------------------------------------------
# PV/PVC 持久化存储配置
# --------------------------------------------------------------------
kubectl get pvc -n dify

# --------------------------------------------------------------------
# 外置独立中间件 StatefulSet 部署(Postgres/Redis/Weaviate)
# --------------------------------------------------------------------
kubectl apply -f external-pg.yaml
kubectl apply -f external-redis.yaml
kubectl apply -f external-weaviate.yaml
# 实时观察pod状态，三个中间件全部Running再执行helm部署
kubectl get pods -n dify -w

# --------------------------------------------------------------------
# Helm4.5 离线部署 Dify 主业务(关闭内置中间件，对接外置服务)
# --------------------------------------------------------------------
mkdir -p /opt/dify-helm && cd /opt/dify-helm
wget https://ghproxy.com/https://github.com/langgenius/dify/archive/refs/tags/v1.16.0.tar.gz
tar -zxvf v1.16.0.tar.gz
cd dify-1.16.0/charts/dify

# --------------------------------------------------------------------
# Helm4.5 离线部署 Dify 主业务(关闭内置中间件，对接外置服务)
# --------------------------------------------------------------------
# 本地Chart安装，Helm4.5标准语法
helm install dify . -n dify -f values-custom.yaml
# 验证部署状态
helm list -n dify
# STATUS=deployed 代表安装成功，等待业务pod启动
kubectl get pods -n dify -w

# --------------------------------------------------------------------
# Ingress 域名访问配置 dify-ingress.yaml
# --------------------------------------------------------------------
kubectl apply -f dify-ingress.yaml
kubectl get ingress -n dify
