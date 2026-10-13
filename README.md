# Dify 企业级 AI 应用平台部署 SOP

把 [Dify](https://github.com/langgenius/dify)（LLM 应用开发平台）从单机 Docker Compose 迁到 Kubernetes 集群的完整落地记录。

内容包含 Helm 部署、中间件外置、镜像统一管理与对外访问配置，以及过程截图。

**部署环境**：Rocky Linux 9 x86_64 / Kubernetes 集群 / Helm 3

---

## 一、这个仓库解决什么问题

Dify 官方给的是 `docker compose` 单机方案，跑起来简单，但作为长期在用的平台有几个问题：

- **没有高可用**：应用和数据库在同一台机器上，机器重启平台就断
- **中间件扩容困难**：Postgres / Redis / Weaviate 和应用绑在一起，想单独调资源做不到
- **镜像拉取受制**：默认走公网仓库，内网环境经常拉不动，需要统一走私有 Harbor
- **数据与访问不可控**：容器删了数据就没了；对外访问也缺少统一的入口和证书配置

这个仓库做的事情就是：把 Dify 的中间件全部外置成独立的 StatefulSet、镜像统一走私有仓库、数据落 PV、访问走 Ingress，形成一套可以重复部署的方案。

## 二、两套部署方案

按场景选一条：

| 方案 | 适用场景 | 组成 |
|---|---|---|
| **方案一：Docker Compose 单机** | 快速验证、个人试用 | 单节点，容器直连，最省事 |
| **方案二：K8s + Helm** | 生产 / 长期使用 | Dify 应用 + 外置 Postgres / Redis / Weaviate + Ingress |

方案二的结构：

```
Ingress (dify.example.com)
   │
   └─ Dify 应用（Web + API + Worker）
        ├─ Postgres   StatefulSet + PV
        ├─ Redis      StatefulSet + PV
        └─ Weaviate   StatefulSet + PV
```

## 三、仓库结构

```
helm/
  values-custom.yaml                外置中间件、私有镜像仓库、资源限额配置
k8s-manifests/
  secret-dify-secrets.example.yaml  凭据示例，复制后填值（不要提交真实凭据）
  statefulset-external-postgres.yaml
  statefulset-external-redis.yaml
  statefulset-external-weaviate.yaml
  ingress-dify-ingress.yaml
scripts/                            按部署顺序编号
  02-前置环境初始化-所有节点必做.sh
  03-方案一-Docker-Compose-单机部署.sh
  04-方案二-K8s-Helm-生产集群部署.sh
  05-部署验证与功能验收.sh
Dify 企业级 AI 应用平台部署 SOP.md    完整 SOP，含逐步截图
images/                             过程截图 15 张
```

## 四、怎么复现

> **关于 `scripts/*.sh`**：这些是**部署过程的操作记录**（含命令输出），不是可直接执行的自动化脚本，按顺序粘贴执行即可。

```bash
# 1. 前置环境（所有节点）
#    关闭 swap、加载内核模块、配好内核参数与时间同步
scripts/02-前置环境初始化-所有节点必做.sh

# 2a. 方案一：单机部署
scripts/03-方案一-Docker-Compose-单机部署.sh

# 2b. 方案二：K8s + Helm（生产）
#     ① 先建凭据（真实口令自己填，仓库里只有 .example 文件）
kubectl create secret generic dify-secrets \
  --from-literal=postgres-password='<你的口令>' \
  --from-literal=redis-password='<你的口令>' \
  --from-literal=weaviate-api-key='<你的 API Key>' \
  -n <命名空间>

#     ② 改 helm/values-custom.yaml 里的镜像仓库地址为你自己的 Harbor
#     ③ 部署中间件与入口
kubectl apply -f k8s-manifests/

#     ④ Helm 部署 Dify 应用（具体 chart 与参数见 SOP 正文）
helm upgrade --install dify <chart> -n <命名空间> -f helm/values-custom.yaml

# 3. 验收
scripts/05-部署验证与功能验收.sh
```

**凭据说明**：仓库里**不保存任何明文口令**。三个 StatefulSet 的凭据全部通过
`secretKeyRef` 引用 `dify-secrets`，Helm values 里也走同样的引用方式；
`secret-dify-secrets.example.yaml` 只是给你复制用的模板。

## 五、完整文档

逐步操作、镜像与存储问题的排查过程、以及每一步的实际输出，都在
[`Dify 企业级 AI 应用平台部署 SOP.md`](./Dify%20企业级%20AI%20应用平台部署%20SOP.md)。
