# Kubernetes 学习项目文档目录

## 文档结构

这个目录包含了 Kubernetes 集群搭建和使用过程中的所有经验教训、最佳实践和故障排查指南。

```
docs/
├── README.md                           # 本文件 - 文档导航
├── lessons-learned-reinstall.md        # 集群重装经验教训
├── lessons-learned-storage.md          # 存储配置经验教训（待添加）
├── lessons-learned-networking.md       # 网络配置经验教训（待添加）
├── lessons-learned-wordpress.md        # WordPress 部署经验教训（待添加）
└── troubleshooting/                    # 故障排查指南
    ├── etcd-recovery.md                # etcd 恢复指南
    ├── network-issues.md               # 网络问题排查
    └── storage-issues.md               # 存储问题排查
```

---

## 📚 已完成的文档

### [集群重装经验教训](lessons-learned-reinstall.md)
**日期**: 2026-01-11
**主题**: 使用 KubeKey 重装 Kubernetes 集群
**关键要点**:
- ⭐ 使用 `KKZONE=cn` 解决镜像拉取问题
- SSH 密钥配置
- sudo 免密配置
- 配置文件格式要求

**适用场景**:
- 在中国大陆环境安装 Kubernetes
- 使用 KubeKey 作为安装工具
- 遇到镜像拉取失败问题

---

## 📝 待添加的文档

### 存储配置经验教训
**预计内容**:
- local-path-provisioner 安装和配置
- StorageClass 配置
- PVC 绑定问题排查
- 数据持久化验证

### 网络配置经验教训
**预计内容**:
- Calico 网络插件配置
- Ingress Controller 安装
- NodePort vs LoadBalancer vs Ingress
- 网络策略 (NetworkPolicy)

### WordPress 部署经验教训
**预计内容**:
- WordPress + MySQL 部署
- Session Affinity 配置
- 多副本部署
- 健康检查配置
- 资源限制配置

---

## 📂 文档编写规范

### 文件命名
- 经验教训: `lessons-learned-<主题>.md`
- 故障排查: `troubleshooting/<问题类型>.md`
- 最佳实践: `best-practices-<主题>.md`

### 文档结构
每个经验教训文档应包含：

1. **背景** - 问题或任务的上下文
2. **核心教训** - 最重要的经验（带 emoji 🎯）
3. **详细步骤** - 完整的解决方案或最佳实践
4. **常见错误** - 症状和解决方案
5. **时间对比** - 错误方式 vs 正确方式（如果适用）
6. **关键要点** - 5个以内的核心总结
7. **参考资源** - 相关文档链接

### Markdown 规范
- 使用清晰的标题层级（# ## ###）
- 代码块使用语言标注（```bash）
- 重要信息使用表格或列表
- 关键步骤使用 emoji 标记
- 错误示例用 ❌，正确示例用 ✅

---

## 🔍 如何使用这些文档

### 场景 1: 遇到问题时
1. 查看对应的 `troubleshooting/` 文档
2. 如果没有，查看相关的 `lessons-learned-` 文档
3. 如果还没解决，记录问题并创建新文档

### 场景 2: 学习新功能时
1. 先查看是否有相关的 `lessons-learned-` 文档
2. 按照文档中的"最佳实践"进行操作
3. 记录新的经验教训

### 场景 3: 重复操作时
1. 直接查看对应文档的"详细步骤"部分
2. 复制粘贴命令（已经过验证）
3. 节省时间，避免重复踩坑

---

## 📊 文档统计

| 类型 | 已完成 | 待添加 | 总计 |
|------|--------|--------|------|
| 经验教训 | 1 | 3 | 4 |
| 故障排查 | 0 | 3 | 3 |
| 最佳实践 | 0 | TBD | TBD |

---

## 🎯 文档目标

1. **可搜索** - 通过关键词快速找到解决方案
2. **可复制** - 命令可以直接复制使用
3. **可验证** - 每个步骤都经过实际验证
4. **可维护** - 随着项目进展持续更新
5. **可分享** - 帮助他人避免相同的问题

---

## 🔗 相关资源

- [主项目 README](../readme.md) - 集群整体情况
- [WordPress IaC 项目](../../wordpress-k8s/) - 应用部署项目
- [KubeKey 官方文档](https://github.com/kubesphere/kubekey)
- [Kubernetes 官方文档](https://kubernetes.io/docs/)

---

**更新时间**: 2026-01-11
**维护者**: 学习过程中持续更新
**版本**: v1.0
