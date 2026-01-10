# Kubernetes WordPress 学习项目 - 会话总结

## 📋 基础环境信息

### **集群配置**
- **安装工具**: KubeKey
- **Kubernetes 版本**: v1.26.5
- **节点配置**:
    - `k8s-master` (192.168.226.131) - Control Plane
    - `k8s-node1` (192.168.226.132) - Worker
    - `k8s-node2` (192.168.226.133) - Worker
- **CNI**: Calico
- **存储**: local-path (默认 StorageClass)
- **Ingress**: Nginx Ingress Controller (NodePort 30028 HTTP, 30000 HTTPS)

### **网络环境**
- **HTTP 代理**: `http://10.0.73.30:7897`
- **镜像拉取命令**:
  ```bash
  sudo HTTP_PROXY=http://10.0.73.30:7897 HTTPS_PROXY=http://10.0.73.30:7897 \
    ctr -n k8s.io image pull <镜像>
  ```

### **重要服务配置**
- **etcd**: systemd 服务 (端口 2379/2380)
    - 配置文件: `/etc/etcd.env`
    - 数据目录: `/var/lib/etcd`
    - Service 文件: `/etc/systemd/system/etcd.service`

---

## 🎓 已完成的学习阶段

### **阶段 1: 健康检查 (Probes)**
✅ Liveness Probe - 容器存活检查  
✅ Readiness Probe - 流量就绪控制  
✅ 探针失败行为验证

### **阶段 2: 资源管理 (Resources)**
✅ Requests vs Limits 概念  
✅ QoS 等级 (Guaranteed/Burstable/BestEffort)  
✅ CPU/Memory 配置最佳实践

### **阶段 3: Ingress 域名访问**
✅ 基础 Ingress 配置  
✅ 多域名路由  
✅ 路径匹配 (Prefix vs Exact)  
✅ 路径重写 (rewrite-target)  
✅ Ingress 注解 (annotations)

### **阶段 4: WordPress 多副本 (部分完成)**
✅ 多副本部署概念  
✅ Session Affinity 理论  
⚠️ 因集群故障未完成实践验证

---

## 🔴 重大故障与恢复经验

### **故障场景**
电脑重启后，Kubernetes 集群无法启动：
```
Error: dial tcp 192.168.226.131:6443: connect: connection refused
```

### **根本原因**
1. **etcd 数据损坏**: 重启导致 etcd 快照文件损坏
   ```
   recovering backend from snapshot error: failed to find database snapshot file
   ```

2. **etcd 集群状态配置错误**:
   ```
   ETCD_INITIAL_CLUSTER_STATE=existing  # ← 错误，应该是 new
   ```

### **完整解决流程**

#### **步骤 1: 启动基础服务**
```bash
# Master 节点
sudo systemctl start containerd
sudo systemctl start kubelet

# Worker 节点
ssh k8s-node1 "sudo systemctl start containerd && sudo systemctl start kubelet"
ssh k8s-node2 "sudo systemctl start containerd && sudo systemctl start kubelet"
```

#### **步骤 2: 诊断 etcd 问题**
```bash
# 检查 etcd 状态
sudo systemctl status etcd

# 查看错误日志
sudo journalctl -xeu etcd --no-pager | tail -100

# 发现问题：
# 1. 数据快照损坏
# 2. ETCD_INITIAL_CLUSTER_STATE=existing (但集群已损坏)
```

#### **步骤 3: 修复 etcd**
```bash
# 1. 停止 etcd
sudo systemctl stop etcd

# 2. 修改配置文件
sudo cp /etc/etcd.env /etc/etcd.env.backup
sudo sed -i 's/ETCD_INITIAL_CLUSTER_STATE=existing/ETCD_INITIAL_CLUSTER_STATE=new/g' /etc/etcd.env

# 3. 清空损坏的数据
sudo mv /var/lib/etcd /var/lib/etcd.backup.$(date +%Y%m%d_%H%M%S)
sudo mkdir -p /var/lib/etcd
sudo chmod 700 /var/lib/etcd

# 4. 重启 etcd
sudo systemctl daemon-reload
sudo systemctl start etcd

# 5. 验证
sudo ss -tulnp | grep 2379  # 应该看到端口监听
```

#### **步骤 4: 恢复集群**
```bash
# 1. 启动 kubelet
sudo systemctl start kubelet
sleep 30

# 2. 检查集群
kubectl get nodes  # 所有节点应该 Ready

# 3. 检查系统组件
kubectl get pods -n kube-system
```

### **数据丢失情况**
- ❌ **etcd 数据**: 所有 Kubernetes 对象定义丢失 (Deployment, Service, Ingress)
- ✅ **PVC 数据**: WordPress 文件、MySQL 数据**不受影响**
- 📝 **关键理解**: etcd 只存储配置，应用数据在 PVC 中独立存储

---

## 💡 核心经验教训

### **1. Infrastructure as Code (IaC) 的重要性**

#### **错误做法** ❌
```
- 手动执行 kubectl apply
- 配置文件散落各处
- 没有版本控制
- 没有备份策略
```

#### **正确做法** ✅
```
- 所有配置文件 Git 管理
- 模块化组织结构
- 自动化部署脚本
- 定期备份 etcd
```

### **2. 标准项目结构**
```
wordpress-k8s/
├── README.md                    # 项目文档
├── manifests/
│   ├── namespace.yaml
│   ├── mysql/
│   │   ├── secret.yaml
│   │   ├── pvc.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── wordpress/
│       ├── pvc.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       └── ingress.yaml
├── scripts/
│   ├── deploy-all.sh           # 一键部署
│   ├── backup-etcd.sh          # etcd 备份
│   └── restore-etcd.sh         # etcd 恢复
└── backups/                    # 备份存储
```

### **3. 生产环境最佳实践**

| 实践 | 目的 | 工具 |
|------|------|------|
| **版本控制** | 配置可追溯、可回滚 | Git |
| **GitOps** | 配置即代码，自动同步 | ArgoCD, Flux |
| **etcd 备份** | 集群配置恢复 | etcdctl, Velero |
| **应用数据备份** | PVC 数据保护 | Velero, Restic |
| **监控告警** | 及时发现问题 | Prometheus, Alertmanager |
| **灾难恢复演练** | 验证恢复流程 | 定期演练 |

### **4. 启动顺序依赖**
```
1. containerd (容器运行时)
   ↓
2. kubelet (节点代理)
   ↓
3. etcd (配置存储) ← 关键！
   ↓
4. kube-apiserver (API 服务器)
   ↓
5. kube-controller-manager
6. kube-scheduler
   ↓
7. 应用 Pod
```

---

## 🚀 当前任务状态

### **待完成**
1. ✅ 创建标准化项目结构
2. ✅ 编写自动化部署脚本
3. ⏳ 执行部署并验证
4. ⏳ 完成阶段 4.2 (Session Affinity 验证)
5. ⏳ 阶段 5: HPA 自动扩缩容

### **下一步操作**
```bash
cd ~/wordpress-k8s
./scripts/deploy-all.sh  # 执行自动化部署
```

---

## 📚 重要知识点总结

### **Kubernetes 标签选择器机制**
- Service Selector 是**包含匹配**，不是精确匹配
- Pod 可以有额外标签，只要包含 Selector 要求的标签即可
- 删除必需标签会导致 Service 不匹配

### **Ingress 工作流程**
```
用户 → Ingress Controller (30028) 
     → 检查 Host 头 
     → 匹配 Ingress 规则 
     → 转发到 Service 
     → 负载均衡到 Pod
```

### **Session Affinity 原理**
- 基于 `ClientIP` 的会话保持
- Service 记录 IP → Pod 的映射
- 默认超时 10800 秒 (3 小时)
- 适用于有状态 Web 应用

### **有状态 vs 无状态应用**
- **WordPress**: 半无状态（Session 在本地，数据在 MySQL）
- **MySQL**: 有状态（需要数据一致性，不能简单多副本）
- **PVC**: 数据独立于 Pod 生命周期

---

## 🔧 常用故障排查命令

```bash
# 集群状态
kubectl get nodes
kubectl get pods -n kube-system
kubectl cluster-info

# etcd 诊断
sudo systemctl status etcd
sudo journalctl -xeu etcd --no-pager | tail -50
sudo ss -tulnp | grep 2379

# 应用诊断
kubectl get all -n wordpress-v2
kubectl describe pod <pod-name> -n wordpress-v2
kubectl logs <pod-name> -n wordpress-v2

# 网络诊断
kubectl get svc -n wordpress-v2
kubectl get endpoints -n wordpress-v2
kubectl get ingress -n wordpress-v2
```

---

## 🎯 新会话开始时的检查清单

```bash
# 1. 检查集群状态
kubectl get nodes

# 2. 检查 etcd
sudo systemctl status etcd

# 3. 检查应用状态
kubectl get all -n wordpress-v2

# 4. 检查 Ingress Controller
kubectl get pods -n ingress-nginx

# 5. 如果需要重新部署
cd ~/wordpress-k8s
./scripts/deploy-all.sh
```

---

**关键教训**: 在生产环境中，这次的数据丢失会导致严重后果。始终保持配置版本化、自动化部署、定期备份！