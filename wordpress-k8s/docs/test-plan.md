# WordPress on Kubernetes - 测试计划

## 测试目标

基于 IaC 原则，小步快跑地完成 Kubernetes WordPress 部署的验证和测试。

## 测试环境

- Kubernetes 集群：v1.26.5
- 节点：3 个（1 master + 2 worker）
- 网络：需要 HTTP 代理访问外网镜像
- 存储：local-path

## 测试阶段

### 阶段 1: 基础设施验证 ✅

**目标**: 确保集群基础组件运行正常

**步骤**:
1. [ ] 检查所有节点状态
2. [ ] 检查 etcd 服务状态
3. [ ] 检查 kube-system 组件
4. [ ] 检查 Ingress Controller

**命令**:
```bash
./scripts/verify.sh
```

**预期结果**:
- 所有节点 Ready
- etcd 健康
- 所有系统 Pods Running

---

### 阶段 2: 首次部署测试 ⏳

**目标**: 验证自动化部署脚本和 manifests 配置

**步骤**:
1. [ ] 执行部署脚本
2. [ ] 验证命名空间创建
3. [ ] 验证 MySQL 部署成功
4. [ ] 验证 WordPress 部署成功
5. [ ] 验证 Ingress 配置正确

**命令**:
```bash
cd /home/intel41/code/kube-202601/wordpress-k8s
./scripts/deploy-all.sh
```

**验证检查点**:
- [ ] MySQL Pod 状态为 Running，就绪检查通过
- [ ] WordPress Pods (3个) 状态为 Running
- [ ] PVC 绑定成功
- [ ] Service 创建成功，Endpoints 正确
- [ ] Ingress 创建成功

**预期输出**:
```
NAME                         READY   STATUS    RESTARTS   AGE
pod/mysql-xxx                1/1     Running   0          1m
pod/wordpress-xxx-1          1/1     Running   0          30s
pod/wordpress-xxx-2          1/1     Running   0          30s
pod/wordpress-xxx-3          1/1     Running   0          30s
```

---

### 阶段 3: 应用功能测试 ⏳

**目标**: 验证 WordPress 应用功能正常

**步骤**:
1. [ ] 配置本地 hosts 文件
2. [ ] 浏览器访问 WordPress 安装页面
3. [ ] 完成 WordPress 初始化
4. [ ] 创建测试文章
5. [ ] 上传测试图片

**访问地址**: http://wordpress.local:30028

**验证检查点**:
- [ ] 安装页面正常显示
- [ ] 能够连接到 MySQL 数据库
- [ ] 安装成功
- [ ] 登录后台成功
- [ ] 创建文章成功
- [ ] 上传图片成功

---

### 阶段 4: Session Affinity 测试 ⏳

**目标**: 验证会话保持功能

**步骤**:
1. [ ] 在每个 WordPress Pod 创建标识文件
2. [ ] 多次 curl 访问，验证返回同一 Pod ID
3. [ ] 浏览器访问，检查 Cookie
4. [ ] 清除 Cookie 后验证切换到其他 Pod

**命令**:
```bash
# 创建标识文件
for pod in $(kubectl get pods -n wordpress-v2 -l app=wordpress -o name); do
  kubectl exec -n wordpress-v2 $pod -- /bin/bash -c "echo \$(hostname) > /var/www/html/pod-id.txt"
done

# 测试访问
for i in {1..10}; do
  curl -s http://wordpress.local:30028/pod-id.txt
  sleep 1
done
```

**预期结果**:
- [ ] 10 次访问返回相同的 Pod ID
- [ ] 浏览器中看到 `wordpress-session` Cookie
- [ ] 清除 Cookie 后可能访问到不同的 Pod

---

### 阶段 5: 健康检查测试 ⏳

**目标**: 验证 Liveness 和 Readiness Probe

**步骤**:
1. [ ] 查看当前 Probe 配置
2. [ ] 手动停止某个 Pod 的 Apache 进程
3. [ ] 观察 Liveness Probe 重启容器
4. [ ] 验证 Readiness Probe 移除不健康的 Pod

**命令**:
```bash
# 选择一个 WordPress Pod
POD=$(kubectl get pods -n wordpress-v2 -l app=wordpress -o name | head -1)

# 查看 Probe 配置
kubectl describe $POD -n wordpress-v2 | grep -A 5 "Liveness\|Readiness"

# 进入 Pod 停止 Apache
kubectl exec -n wordpress-v2 $POD -- pkill apache2

# 观察 Pod 状态
kubectl get pods -n wordpress-v2 -w
```

**预期结果**:
- [ ] Apache 停止后，Liveness Probe 失败
- [ ] 容器自动重启
- [ ] Readiness Probe 失败期间，Pod 从 Endpoints 移除

---

### 阶段 6: 资源限制测试 ⏳

**目标**: 验证资源请求和限制配置

**步骤**:
1. [ ] 查看当前资源配置
2. [ ] 查看实际资源使用
3. [ ] 修改资源限制测试更新

**命令**:
```bash
# 查看资源配置
kubectl describe deployment/wordpress -n wordpress-v2 | grep -A 10 "Limits\|Requests"

# 查看实际使用
kubectl top pods -n wordpress-v2
kubectl top nodes

# 查看 QoS 等级
kubectl get pods -n wordpress-v2 -o json | jq '.items[] | {name:.metadata.name, qos:.status.qosClass}'
```

**预期结果**:
- [ ] WordPress Pods: Burstable QoS (有 requests 和 limits)
- [ ] MySQL Pod: Burstable QoS
- [ ] 资源使用在配置范围内

---

### 阶段 7: 持久化存储测试 ⏳

**目标**: 验证数据持久化

**步骤**:
1. [ ] 在 WordPress 创建测试数据
2. [ ] 删除 WordPress Pods
3. [ ] 验证新 Pods 启动后数据依然存在
4. [ ] 检查 MySQL 数据持久化

**命令**:
```bash
# 删除所有 WordPress Pods
kubectl delete pods -n wordpress-v2 -l app=wordpress

# 等待新 Pods 启动
kubectl wait --for=condition=ready pod -l app=wordpress -n wordpress-v2 --timeout=120s

# 再次访问 WordPress
curl http://wordpress.local:30028
```

**预期结果**:
- [ ] 删除 Pods 后自动重建
- [ ] 之前创建的文章依然存在
- [ ] 上传的图片依然可访问
- [ ] 数据库数据完整

---

### 阶段 8: 扩缩容测试 ⏳

**目标**: 验证 WordPress 多副本扩缩容

**步骤**:
1. [ ] 扩容到 5 个副本
2. [ ] 验证所有副本就绪
3. [ ] 缩容到 1 个副本
4. [ ] 验证服务正常

**命令**:
```bash
# 扩容
kubectl scale deployment/wordpress -n wordpress-v2 --replicas=5
kubectl get pods -n wordpress-v2 -w

# 缩容
kubectl scale deployment/wordpress -n wordpress-v2 --replicas=1
kubectl get pods -n wordpress-v2 -w

# 恢复到 3 个副本
kubectl scale deployment/wordpress -n wordpress-v2 --replicas=3
```

**预期结果**:
- [ ] 扩容后 5 个 Pods 都 Running
- [ ] Service 负载均衡到所有 Pods
- [ ] 缩容后应用仍可访问
- [ ] 数据不丢失

---

### 阶段 9: etcd 备份测试 ⏳

**目标**: 验证 etcd 备份功能

**步骤**:
1. [ ] 执行 etcd 备份脚本
2. [ ] 验证备份文件生成
3. [ ] 验证备份文件完整性

**命令**:
```bash
./scripts/backup-etcd.sh
ls -lh backups/
```

**预期结果**:
- [ ] 备份脚本执行成功
- [ ] 生成 .db 备份文件
- [ ] 快照验证通过

---

### 阶段 10: 灾难恢复演练 ⚠️ (可选，风险较高)

**目标**: 验证从 etcd 备份恢复集群

**警告**: 此测试会清空当前 etcd 数据！

**步骤**:
1. [ ] 确保已有有效备份
2. [ ] 记录当前所有资源状态
3. [ ] 执行恢复脚本
4. [ ] 验证集群恢复
5. [ ] 重新部署应用

**命令**:
```bash
# 备份当前状态
kubectl get all,pvc,ingress -n wordpress-v2 > /tmp/before-restore.txt

# 执行恢复（谨慎！）
./scripts/restore-etcd.sh

# 验证恢复
./scripts/verify.sh

# 重新部署应用
./scripts/deploy-all.sh
```

**预期结果**:
- [ ] etcd 恢复成功
- [ ] 集群组件正常
- [ ] 应用可以重新部署
- [ ] PVC 数据未丢失

---

### 阶段 11: 清理和重建测试 ⏳

**目标**: 验证清理和重建流程

**步骤**:
1. [ ] 执行清理脚本（保留 PVC）
2. [ ] 验证资源清理
3. [ ] 重新部署
4. [ ] 验证数据恢复

**命令**:
```bash
# 清理
./scripts/delete-all.sh

# 重新部署
./scripts/deploy-all.sh

# 验证
./scripts/verify.sh
```

**预期结果**:
- [ ] 应用资源清理干净
- [ ] PVC 和数据保留
- [ ] 重新部署成功
- [ ] WordPress 数据完整

---

## 测试记录

### 测试日期: ___________

**测试人员**: ___________

**环境信息**:
- Kubernetes 版本: v1.26.5
- 节点数量: 3
- 网络代理: http://10.0.73.30:7897

**测试结果汇总**:

| 阶段 | 状态 | 备注 |
|------|------|------|
| 1. 基础设施验证 | ☐ 通过 / ☐ 失败 | |
| 2. 首次部署测试 | ☐ 通过 / ☐ 失败 | |
| 3. 应用功能测试 | ☐ 通过 / ☐ 失败 | |
| 4. Session Affinity | ☐ 通过 / ☐ 失败 | |
| 5. 健康检查测试 | ☐ 通过 / ☐ 失败 | |
| 6. 资源限制测试 | ☐ 通过 / ☐ 失败 | |
| 7. 持久化存储 | ☐ 通过 / ☐ 失败 | |
| 8. 扩缩容测试 | ☐ 通过 / ☐ 失败 | |
| 9. etcd 备份 | ☐ 通过 / ☐ 失败 | |
| 10. 灾难恢复 | ☐ 通过 / ☐ 失败 / ☐ 跳过 | |
| 11. 清理重建 | ☐ 通过 / ☐ 失败 | |

**遇到的问题**:

1.
2.
3.

**解决方案**:

1.
2.
3.

**改进建议**:

1.
2.
3.

---

## 下一步计划

完成测试后的学习方向：

- [ ] HPA (Horizontal Pod Autoscaler) 自动扩缩容
- [ ] 监控集成 (Prometheus + Grafana)
- [ ] 日志收集 (EFK Stack)
- [ ] CI/CD 集成 (GitOps with ArgoCD)
- [ ] 安全加固 (NetworkPolicy, PodSecurityPolicy)
