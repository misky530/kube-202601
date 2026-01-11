# Kubernetes 学习项目 - 项目结构

## 整体结构

```
kube-202601/
├── kubekey-local/                      # KubeKey 集群相关
│   ├── readme.md                       # 集群基础信息和第一次故障记录
│   ├── PROJECT-STRUCTURE.md            # 本文件 - 项目结构说明
│   └── docs/                           # 📚 文档中心
│       ├── README.md                   # 文档导航
│       ├── lessons-learned-reinstall.md # 集群重装经验
│       ├── lessons-learned-storage.md  # 存储经验（待添加）
│       ├── lessons-learned-networking.md # 网络经验（待添加）
│       ├── lessons-learned-wordpress.md # WordPress 经验（待添加）
│       └── troubleshooting/            # 故障排查指南
│           ├── etcd-recovery.md
│           ├── network-issues.md
│           └── storage-issues.md
│
└── wordpress-k8s/                      # WordPress IaC 项目
    ├── README.md                       # 项目说明
    ├── PROJECT-STATUS.md               # 当前状态
    ├── .gitignore                      # Git 忽略配置
    ├── manifests/                      # Kubernetes 配置文件
    │   ├── namespace.yaml
    │   ├── mysql/                      # MySQL 相关
    │   │   ├── secret.yaml
    │   │   ├── pvc.yaml
    │   │   ├── deployment.yaml
    │   │   └── service.yaml
    │   └── wordpress/                  # WordPress 相关
    │       ├── pvc.yaml
    │       ├── deployment.yaml
    │       ├── service.yaml
    │       └── ingress.yaml
    ├── scripts/                        # 自动化脚本
    │   ├── deploy-all.sh               # 一键部署
    │   ├── delete-all.sh               # 清理资源
    │   ├── verify.sh                   # 验证集群
    │   ├── backup-etcd.sh              # etcd 备份
    │   └── restore-etcd.sh             # etcd 恢复
    ├── backups/                        # 备份存储
    └── docs/                           # 项目文档
        ├── quick-reference.md          # 快速参考
        └── test-plan.md                # 测试计划
```

---

## 目录说明

### kubekey-local/
**用途**: Kubernetes 集群基础设施相关

**包含内容**:
- 集群配置信息
- 故障恢复经验
- 集群管理文档

**关键文件**:
- `readme.md`: 集群基础信息、第一次 etcd 故障记录
- `docs/`: 所有经验教训和故障排查文档

---

### wordpress-k8s/
**用途**: 应用层面的 IaC 实践

**包含内容**:
- WordPress + MySQL 部署配置
- 自动化脚本
- 应用级别的文档

**关键目录**:
- `manifests/`: 所有 Kubernetes 资源定义
- `scripts/`: 自动化运维脚本
- `docs/`: 应用部署和测试文档

---

## 文档分类

### 集群层面文档 (kubekey-local/docs/)
- 集群安装和重装
- 网络插件配置
- 存储类配置
- etcd 管理

### 应用层面文档 (wordpress-k8s/docs/)
- 应用部署流程
- 测试计划和验证
- 运维操作手册
- 故障排查（应用级别）

---

## 使用指南

### 场景 1: 初次搭建集群
1. 查看 `kubekey-local/readme.md` 了解环境
2. 阅读 `kubekey-local/docs/lessons-learned-reinstall.md`
3. 使用正确的方法安装（`KKZONE=cn`）

### 场景 2: 部署 WordPress
1. 查看 `wordpress-k8s/README.md` 了解项目
2. 阅读 `wordpress-k8s/PROJECT-STATUS.md` 了解当前状态
3. 执行 `wordpress-k8s/scripts/deploy-all.sh`
4. 参考 `wordpress-k8s/docs/test-plan.md` 进行测试

### 场景 3: 遇到问题
1. 先确定是集群问题还是应用问题
2. 集群问题 → `kubekey-local/docs/troubleshooting/`
3. 应用问题 → `wordpress-k8s/docs/`
4. 如果找不到 → 记录并创建新文档

### 场景 4: 添加新功能
1. 在 `wordpress-k8s/manifests/` 添加配置
2. 更新 `wordpress-k8s/scripts/` 脚本
3. 在 `wordpress-k8s/docs/` 记录经验
4. 更新 `wordpress-k8s/PROJECT-STATUS.md`

---

## 设计原则

### 1. 关注点分离
- **kubekey-local**: 集群基础设施
- **wordpress-k8s**: 应用部署

### 2. Infrastructure as Code
- 所有配置都是代码
- 版本控制
- 可重复部署

### 3. 文档驱动
- 每个操作都有文档
- 经验教训及时记录
- 故障排查有据可查

### 4. 自动化优先
- 脚本化常用操作
- 减少手动步骤
- 降低出错概率

---

## Git 管理建议

### .gitignore 配置
```
# 备份文件
backups/*.db
backups/*.tar.gz

# 临时文件
*.tmp
*.log

# 敏感信息（如果有）
*secret*.yaml.bak
```

### 提交规范
```bash
# 集群相关
git commit -m "docs: 添加集群重装经验教训"
git commit -m "fix: 修复 etcd 恢复脚本"

# 应用相关
git commit -m "feat: 添加 WordPress 部署配置"
git commit -m "docs: 更新测试计划"
```

---

## 未来扩展

### 可能添加的目录

```
kube-202601/
├── monitoring/                 # 监控配置（Prometheus + Grafana）
├── logging/                    # 日志收集（EFK Stack）
├── security/                   # 安全配置（NetworkPolicy, RBAC）
└── cicd/                      # CI/CD 配置（GitOps）
```

### 可能添加的文档

- `best-practices-security.md` - 安全最佳实践
- `best-practices-performance.md` - 性能优化
- `lessons-learned-monitoring.md` - 监控经验
- `lessons-learned-cicd.md` - CI/CD 经验

---

## 版本历史

- **v1.0** (2026-01-11): 初始项目结构，包含集群重装文档
- **v1.1** (待定): 添加存储和网络文档
- **v1.2** (待定): 完成 WordPress 部署文档

---

**创建时间**: 2026-01-11
**最后更新**: 2026-01-11
**维护原则**: 随项目进展持续更新
