# WordPress on Kubernetes - 快速参考

## 常用命令

### 部署和管理

```bash
# 一键部署所有资源
cd /home/intel41/code/kube-202601/wordpress-k8s
./scripts/deploy-all.sh

# 验证部署状态
./scripts/verify.sh

# 清理资源（保留数据）
./scripts/delete-all.sh

# 备份 etcd
./scripts/backup-etcd.sh

# 从备份恢复 etcd
./scripts/restore-etcd.sh
```

### 查看资源状态

```bash
# 查看所有资源
kubectl get all,pvc,ingress -n wordpress-v2

# 查看 Pods
kubectl get pods -n wordpress-v2 -o wide

# 查看 Pod 日志
kubectl logs -f deployment/wordpress -n wordpress-v2
kubectl logs -f deployment/mysql -n wordpress-v2

# 查看 Pod 详细信息
kubectl describe pod <pod-name> -n wordpress-v2

# 查看 Ingress
kubectl get ingress -n wordpress-v2
kubectl describe ingress wordpress-ingress -n wordpress-v2
```

### 调试命令

```bash
# 进入 WordPress Pod
kubectl exec -it deployment/wordpress -n wordpress-v2 -- /bin/bash

# 进入 MySQL Pod
kubectl exec -it deployment/mysql -n wordpress-v2 -- /bin/bash

# 在 MySQL Pod 中连接数据库
kubectl exec -it deployment/mysql -n wordpress-v2 -- mysql -u root -prootpassword123

# 测试 Service 连接
kubectl run -it --rm debug --image=busybox --restart=Never -n wordpress-v2 -- sh
# 在容器中执行：
# wget -O- http://wordpress
# nslookup mysql
```

### 测试 Session Affinity

```bash
# 查看当前运行的 WordPress Pods
kubectl get pods -n wordpress-v2 -l app=wordpress -o wide

# 在每个 Pod 中创建标识文件
kubectl exec -n wordpress-v2 deployment/wordpress -- /bin/bash -c "echo \$(hostname) > /var/www/html/pod-id.txt"

# 多次访问，检查是否总是返回相同的 Pod ID（测试 Session Affinity）
for i in {1..10}; do
  curl -s http://wordpress.local:30028/pod-id.txt
  sleep 1
done

# 查看 Service 的 Endpoints（显示所有后端 Pod）
kubectl get endpoints -n wordpress-v2 wordpress
```

### 扩容和缩容

```bash
# 扩容 WordPress 到 5 个副本
kubectl scale deployment/wordpress -n wordpress-v2 --replicas=5

# 缩容到 1 个副本
kubectl scale deployment/wordpress -n wordpress-v2 --replicas=1

# 查看扩容状态
kubectl get pods -n wordpress-v2 -l app=wordpress -w
```

### 更新配置

```bash
# 编辑 Deployment
kubectl edit deployment/wordpress -n wordpress-v2

# 或者修改 YAML 文件后重新应用
vi manifests/wordpress/deployment.yaml
kubectl apply -f manifests/wordpress/deployment.yaml

# 查看 rollout 状态
kubectl rollout status deployment/wordpress -n wordpress-v2

# 查看 rollout 历史
kubectl rollout history deployment/wordpress -n wordpress-v2

# 回滚到上一个版本
kubectl rollout undo deployment/wordpress -n wordpress-v2
```

## 访问应用

### 配置 hosts

在本地机器（非 K8s 集群）添加：

```bash
sudo bash -c 'cat >> /etc/hosts <<EOF
192.168.226.131 wordpress.local
192.168.226.132 wordpress.local
192.168.226.133 wordpress.local
EOF'
```

### 访问 WordPress

浏览器打开：http://wordpress.local:30028

## 故障排查

### 集群启动问题

```bash
# 检查节点状态
kubectl get nodes

# 检查系统组件
kubectl get pods -n kube-system

# 检查 etcd 状态
sudo systemctl status etcd
sudo journalctl -xeu etcd --no-pager | tail -50

# 检查 kubelet 日志
sudo journalctl -xeu kubelet --no-pager | tail -50
```

### Pod 启动失败

```bash
# 查看 Pod 事件
kubectl describe pod <pod-name> -n wordpress-v2

# 查看容器日志
kubectl logs <pod-name> -n wordpress-v2

# 查看前一个容器的日志（如果 Pod 重启过）
kubectl logs <pod-name> -n wordpress-v2 --previous

# 检查镜像拉取
# 如果需要代理，在节点上执行：
sudo HTTP_PROXY=http://10.0.73.30:7897 HTTPS_PROXY=http://10.0.73.30:7897 \
  ctr -n k8s.io image pull <镜像名>
```

### 网络问题

```bash
# 检查 Service
kubectl get svc -n wordpress-v2
kubectl get endpoints -n wordpress-v2

# 检查 Ingress Controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# 测试 NodePort
curl http://192.168.226.131:30028
```

### 存储问题

```bash
# 查看 PVC 状态
kubectl get pvc -n wordpress-v2

# 查看 PV
kubectl get pv

# 查看 StorageClass
kubectl get storageclass
```

## 常见问题

### Q: etcd 启动失败

检查 `/etc/etcd.env` 中的 `ETCD_INITIAL_CLUSTER_STATE`：
- 首次启动或数据损坏后：应该是 `new`
- 从备份恢复后：应该是 `existing`

### Q: Pod 无法拉取镜像

在节点上手动拉取：
```bash
sudo HTTP_PROXY=http://10.0.73.30:7897 HTTPS_PROXY=http://10.0.73.30:7897 \
  ctr -n k8s.io image pull <镜像>
```

### Q: Ingress 无法访问

1. 检查 Ingress Controller 是否运行
2. 检查 NodePort 端口（30028）
3. 检查 hosts 配置
4. 查看 Ingress Controller 日志

## 学习实验

### 实验 1: Session Affinity 测试

1. 部署 3 个 WordPress 副本
2. 在每个 Pod 创建标识文件
3. 通过 curl 多次访问，验证总是访问同一个 Pod
4. 清除浏览器 Cookie，验证会切换到其他 Pod

### 实验 2: 健康检查测试

1. 手动停止某个 Pod 的 Apache 进程
2. 观察 Liveness Probe 检测失败并重启容器
3. 验证 Readiness Probe 将 Pod 从 Service 移除

### 实验 3: 资源限制测试

1. 压测 WordPress，观察资源使用
2. 修改 resources limits，观察 Pod 重建
3. 设置过低的 limits，观察 OOMKilled

### 实验 4: 滚动更新测试

1. 修改 WordPress 镜像版本
2. 观察滚动更新过程
3. 测试回滚功能

## 维护清单

### 每日
- [ ] 检查集群节点状态
- [ ] 检查应用 Pods 状态
- [ ] 查看异常日志

### 每周
- [ ] 备份 etcd
- [ ] 清理旧的日志和备份
- [ ] 检查资源使用情况

### 每月
- [ ] 测试 etcd 恢复流程
- [ ] 更新文档
- [ ] 回顾和优化配置
