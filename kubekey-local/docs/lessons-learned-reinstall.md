# Kubernetes 集群重装经验教训 - 2026-01-11

## 背景

由于之前的集群缺少 Calico 和 kube-proxy 等关键网络组件，导致 Pod 无法创建网络，决定使用 KubeKey 完全重装集群。

---

## 核心教训

### 🎯 教训 1: 使用 KubeKey 的中国区优化（最重要！）

**问题**：
- 最初尝试配置 containerd 代理来拉取 Docker Hub 镜像
- 即使配置了代理，仍然频繁失败：`EOF`、连接超时等
- 浪费了大量时间调试代理配置

**正确方案**：
```bash
# 只需要一个环境变量！
export KKZONE=cn
sudo -E ~/kk create cluster -f cluster-config.yaml
```

**效果对比**：

| 方案 | 镜像源 | 成功率 | 速度 |
|------|--------|--------|------|
| 默认（Docker Hub） | registry-1.docker.io | ❌ 频繁失败 | 极慢/超时 |
| 配置代理 | registry-1.docker.io (通过代理) | ⚠️ 不稳定 | 慢 |
| **KKZONE=cn** | registry.cn-beijing.aliyuncs.com | ✅ 100% 成功 | **极快** |

**关键代码**：
```bash
# KubeKey 会自动使用阿里云镜像：
# registry.cn-beijing.aliyuncs.com/kubesphereio/pause:3.8
# registry.cn-beijing.aliyuncs.com/kubesphereio/kube-apiserver:v1.26.5
# registry.cn-beijing.aliyuncs.com/kubesphereio/calico-node:v3.26.1
```

**参考文档**：
- https://github.com/kubesphere/kubekey

---

### 🎯 教训 2: KubeKey 需要 SSH 密钥和 sudo 免密

**问题 1: SSH 认证失败**
```
failed to connect: ssh: handshake failed: ssh: unable to authenticate
```

**解决方案**：
```bash
# 1. 生成 SSH 密钥
ssh-keygen -t rsa -b 2048 -N "" -f ~/.ssh/id_rsa

# 2. 分发公钥到所有节点（包括本机）
ssh-copy-id caiqian@192.168.226.131
ssh-copy-id caiqian@192.168.226.132
ssh-copy-id caiqian@192.168.226.133

# 3. 如果用 sudo 执行 kk，需要复制密钥给 root
sudo mkdir -p /root/.ssh
sudo cp ~/.ssh/id_rsa /root/.ssh/
sudo cp ~/.ssh/id_rsa.pub /root/.ssh/
sudo chmod 600 /root/.ssh/id_rsa
```

**问题 2: sudo 需要密码**
```
Failed to exec command: sudo -E /bin/bash -c "..."
[sudo] password for caiqian:
sudo: 3 incorrect password attempts
```

**解决方案**（在**所有节点**上配置）：
```bash
# 在每个节点上执行
echo "caiqian ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/caiqian
sudo chmod 0440 /etc/sudoers.d/caiqian

# 验证
sudo echo "sudo works"
```

---

### 🎯 教训 3: KubeKey 配置文件格式很严格

**错误示例**（导致 "The number of master/control-plane cannot be 0"）：
```yaml
roleGroups:
  etcd:
  - k8s-master
  control-plane:      # ❌ 缺少空格
  - k8s-master
```

**正确格式**：
```yaml
roleGroups:
  etcd:
  - k8s-master
  control-plane:      # ✅ 冒号后有空格
  - k8s-master
```

**生成配置文件的正确方法**：
```bash
# 让 KubeKey 自己生成示例配置
~/kk create config --name k8s-cluster --with-kubernetes v1.26.5

# 然后修改生成的配置文件
```

---

### 🎯 教训 4: 小步快跑的重要性

**采用的策略**：
1. ✅ 先解决 SSH 认证问题
2. ✅ 再解决 sudo 免密问题
3. ✅ 然后解决配置文件格式问题
4. ✅ 再解决镜像拉取问题（KKZONE=cn）
5. ✅ 最后验证集群

**避免的错误**：
- ❌ 同时解决所有问题
- ❌ 跳过验证步骤
- ❌ 不确认每步是否成功就继续

---

## 完整的重装流程（最佳实践）

### 前置准备

```bash
# 1. 在所有节点配置 SSH 密钥
ssh-keygen -t rsa -b 2048 -N "" -f ~/.ssh/id_rsa
ssh-copy-id caiqian@192.168.226.131
ssh-copy-id caiqian@192.168.226.132
ssh-copy-id caiqian@192.168.226.133

# 2. 在所有节点配置 sudo 免密
# 在 master
echo "caiqian ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/caiqian
# 在 node1
ssh k8s-node1 "echo 'caiqian ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/caiqian && sudo chmod 0440 /etc/sudoers.d/caiqian"
# 在 node2
ssh k8s-node2 "echo 'caiqian ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/caiqian && sudo chmod 0440 /etc/sudoers.d/caiqian"

# 3. 如果需要用 sudo 执行 kk，复制 SSH 密钥给 root
sudo mkdir -p /root/.ssh
sudo cp ~/.ssh/id_rsa /root/.ssh/
sudo cp ~/.ssh/id_rsa.pub /root/.ssh/
sudo chmod 600 /root/.ssh/id_rsa
```

### 创建配置文件

```bash
cd ~/kubekey

# 生成配置文件模板
~/kk create config --name k8s-cluster --with-kubernetes v1.26.5

# 编辑配置文件，修改节点信息
cat > cluster-config.yaml << 'EOF'
apiVersion: kubekey.kubesphere.io/v1alpha2
kind: Cluster
metadata:
  name: k8s-cluster
spec:
  hosts:
  - {name: k8s-master, address: 192.168.226.131, internalAddress: 192.168.226.131, user: caiqian, password: ""}
  - {name: k8s-node1, address: 192.168.226.132, internalAddress: 192.168.226.132, user: caiqian, password: ""}
  - {name: k8s-node2, address: 192.168.226.133, internalAddress: 192.168.226.133, user: caiqian, password: ""}
  roleGroups:
    etcd:
    - k8s-master
    control-plane:     # 注意：冒号后有空格
    - k8s-master
    worker:
    - k8s-node1
    - k8s-node2
  controlPlaneEndpoint:
    domain: lb.kubesphere.local
    address: ""
    port: 6443
  kubernetes:
    version: v1.26.5
    clusterName: cluster.local
    autoRenewCerts: true
    containerManager: containerd
  etcd:
    type: kubekey
  network:
    plugin: calico
    kubePodsCIDR: 10.233.64.0/18
    kubeServiceCIDR: 10.233.0.0/18
    multusCNI:
      enabled: false
  registry:
    privateRegistry: ""
    namespaceOverride: ""
    registryMirrors: []
    insecureRegistries: []
  addons: []
EOF
```

### 删除旧集群

```bash
cd ~/kubekey

# 使用 KubeKey 删除（如果之前安装过）
sudo ~/kk delete cluster -f cluster-config.yaml
```

### 重新安装集群（关键！）

```bash
# 设置中国区环境变量（最重要！）
export KKZONE=cn

# 使用 -E 保留环境变量
sudo -E ~/kk create cluster -f cluster-config.yaml
```

### 验证安装

```bash
# 检查所有 Pods
kubectl get pods -A

# 检查节点
kubectl get nodes -o wide

# 验证网络组件
kubectl get pods -n kube-system | grep -E "calico|kube-proxy"
```

**预期结果**：
```
kube-system   calico-kube-controllers-xxx   1/1     Running
kube-system   calico-node-xxx               1/1     Running  (3个)
kube-system   kube-proxy-xxx                1/1     Running  (3个)
```

---

## 常见错误排查

### 错误 1: 镜像拉取失败

**症状**：
```
failed to pull and unpack image: failed to resolve reference: EOF
failed to authorize: failed to fetch anonymous token: EOF
```

**解决方案**：
```bash
# 确保使用 KKZONE=cn
export KKZONE=cn
sudo -E ~/kk create cluster -f cluster-config.yaml
```

### 错误 2: SSH 连接失败

**症状**：
```
failed to connect: ssh: handshake failed
```

**解决方案**：
```bash
# 检查 SSH 密钥
ls -la ~/.ssh/id_rsa*

# 如果用 sudo，检查 root 的密钥
sudo ls -la /root/.ssh/id_rsa*

# 测试 SSH 连接
ssh caiqian@192.168.226.131 "echo OK"
```

### 错误 3: sudo 密码问题

**症状**：
```
[sudo] password for caiqian:
sudo: 3 incorrect password attempts
```

**解决方案**：
```bash
# 在对应节点配置 sudo 免密
echo "caiqian ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/caiqian
sudo chmod 0440 /etc/sudoers.d/caiqian
```

### 错误 4: control-plane 数量为 0

**症状**：
```
The number of master/control-plane cannot be 0
```

**解决方案**：
检查配置文件中 `control-plane:` 后面是否有空格

---

## 时间对比

| 阶段 | 错误方式（用代理） | 正确方式（KKZONE=cn） |
|------|-------------------|---------------------|
| 准备工作 | 30分钟 | 10分钟 |
| 镜像拉取 | 失败或超时 | 2分钟 |
| 集群安装 | N/A | 3分钟 |
| **总计** | **失败** | **15分钟** |

---

## 关键要点总结

1. **🥇 最重要：使用 `KKZONE=cn`**
   - 不需要配置代理
   - 不需要修改 containerd 配置
   - 镜像拉取速度极快且稳定

2. **SSH 认证**：
   - 生成密钥对
   - 分发到所有节点
   - 如果用 sudo，复制给 root

3. **sudo 免密**：
   - 在所有节点配置 `/etc/sudoers.d/`
   - 避免安装过程中断

4. **配置文件格式**：
   - 使用 KubeKey 自动生成模板
   - 注意 YAML 格式（空格、缩进）

5. **小步验证**：
   - 每步都验证是否成功
   - 不要急于进入下一步

---

## 后续建议

1. **定期备份 etcd**：
   ```bash
   cd /home/intel41/code/kube-202601/wordpress-k8s
   ./scripts/backup-etcd.sh
   ```

2. **保存配置文件**：
   ```bash
   # 将 cluster-config.yaml 纳入版本控制
   cp ~/kubekey/cluster-config.yaml /home/intel41/code/kube-202601/kubekey-local/
   ```

3. **文档化环境变量**：
   在 README 中记录需要设置 `KKZONE=cn`

4. **定期演练**：
   每月至少演练一次集群重装流程

---

## 参考资源

- KubeKey GitHub: https://github.com/kubesphere/kubekey
- KubeKey 中国区镜像: 自动使用阿里云 `registry.cn-beijing.aliyuncs.com`
- Kubernetes 文档: https://kubernetes.io/docs/

---

**日期**: 2026-01-11
**耗时**: 约 8 小时（从发现问题到成功重装）
**最大收获**: `export KKZONE=cn` 这一个环境变量解决了所有镜像拉取问题！

**记住**: 在中国大陆使用 KubeKey 安装 Kubernetes，**第一步就是设置 `KKZONE=cn`**！
