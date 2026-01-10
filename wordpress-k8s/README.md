# WordPress on Kubernetes - IaC 项目

## 项目概述

基于 Infrastructure as Code 原则的 WordPress Kubernetes 部署项目。
吸取 etcd 故障导致配置丢失的教训，采用完全代码化、版本控制的方式管理集群配置。

## 集群环境

- **Kubernetes 版本**: v1.26.5
- **节点**:
  - k8s-master (192.168.226.131) - Control Plane
  - k8s-node1 (192.168.226.132) - Worker
  - k8s-node2 (192.168.226.133) - Worker
- **CNI**: Calico
- **存储**: local-path (默认 StorageClass)
- **Ingress**: Nginx Ingress Controller (NodePort 30028 HTTP, 30000 HTTPS)
- **HTTP 代理**: http://10.0.73.30:7897

## 项目结构

```
wordpress-k8s/
├── README.md                    # 项目文档
├── manifests/                   # Kubernetes 配置文件
│   ├── namespace.yaml           # 命名空间
│   ├── mysql/                   # MySQL 相关配置
│   │   ├── secret.yaml          # 数据库密码
│   │   ├── pvc.yaml             # 持久化存储
│   │   ├── deployment.yaml      # 部署配置
│   │   └── service.yaml         # 服务配置
│   └── wordpress/               # WordPress 相关配置
│       ├── pvc.yaml             # 持久化存储
│       ├── deployment.yaml      # 部署配置
│       ├── service.yaml         # 服务配置
│       └── ingress.yaml         # Ingress 路由
├── scripts/                     # 自动化脚本
│   ├── deploy-all.sh            # 一键部署所有资源
│   ├── delete-all.sh            # 清理所有资源
│   ├── backup-etcd.sh           # etcd 备份
│   └── restore-etcd.sh          # etcd 恢复
├── backups/                     # 备份存储目录
└── docs/                        # 其他文档
```

## 快速开始

### 部署应用

```bash
cd /home/intel41/code/kube-202601/wordpress-k8s
./scripts/deploy-all.sh
```

### 清理资源

```bash
./scripts/delete-all.sh
```

### 备份 etcd

```bash
./scripts/backup-etcd.sh
```

## 访问应用

- **WordPress 地址**: http://wordpress.local:30028 (需要配置 hosts)
- **配置 hosts**: 在本地机器的 /etc/hosts 添加:
  ```
  192.168.226.131 wordpress.local
  192.168.226.132 wordpress.local
  192.168.226.133 wordpress.local
  ```

## IaC 原则

1. 所有配置都以 YAML 文件形式存储
2. 所有文件纳入 Git 版本控制
3. 使用脚本自动化部署和维护
4. 定期备份 etcd
5. 禁止手动 kubectl apply 临时配置

## 学习目标

- [x] 健康检查 (Probes)
- [x] 资源管理 (Resources)
- [x] Ingress 域名访问
- [ ] WordPress 多副本 + Session Affinity
- [ ] HPA 自动扩缩容
- [ ] 监控与日志收集

## 故障恢复

参考 [kubekey-local/readme.md](../kubekey-local/readme.md) 中的完整故障恢复流程。

## 版本历史

- v1.0 - 初始 IaC 项目结构 (2026-01-10)
