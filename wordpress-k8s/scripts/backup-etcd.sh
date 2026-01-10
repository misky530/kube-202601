#!/bin/bash

##############################################
# etcd 备份脚本
# 功能：备份 etcd 数据，防止集群配置丢失
##############################################

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/etcd-backup-$TIMESTAMP.db"

# etcd 配置
ETCD_ENDPOINTS="https://127.0.0.1:2379"
ETCD_CERT_DIR="/etc/ssl/etcd/ssl"

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  etcd 备份工具${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# 检查是否在 master 节点
if [ ! -f "/etc/etcd.env" ]; then
    echo -e "${RED}错误: 此脚本必须在 k8s-master 节点上运行${NC}"
    exit 1
fi

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 检查 etcdctl 是否可用
if ! command -v etcdctl &> /dev/null; then
    echo -e "${RED}错误: etcdctl 命令未找到${NC}"
    echo -e "${YELLOW}请安装 etcd-client 或使用容器版本${NC}"
    exit 1
fi

# 检查 etcd 是否运行
if ! sudo systemctl is-active --quiet etcd; then
    echo -e "${RED}错误: etcd 服务未运行${NC}"
    echo -e "${YELLOW}请先启动 etcd: sudo systemctl start etcd${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/3] 检查 etcd 健康状态...${NC}"
# 使用 sudo 执行 etcdctl，因为证书需要 root 权限
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=$ETCD_ENDPOINTS \
  --cacert=$ETCD_CERT_DIR/ca.pem \
  --cert=$ETCD_CERT_DIR/admin-k8s-master.pem \
  --key=$ETCD_CERT_DIR/admin-k8s-master-key.pem \
  endpoint health

echo -e "${GREEN}✓ etcd 健康检查通过${NC}"
echo ""

echo -e "${YELLOW}[2/3] 创建 etcd 快照...${NC}"
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=$ETCD_ENDPOINTS \
  --cacert=$ETCD_CERT_DIR/ca.pem \
  --cert=$ETCD_CERT_DIR/admin-k8s-master.pem \
  --key=$ETCD_CERT_DIR/admin-k8s-master-key.pem \
  snapshot save "$BACKUP_FILE"

echo -e "${GREEN}✓ 快照创建成功${NC}"
echo ""

echo -e "${YELLOW}[3/3] 验证快照完整性...${NC}"
sudo ETCDCTL_API=3 etcdctl snapshot status "$BACKUP_FILE" -w table

echo -e "${GREEN}✓ 快照验证通过${NC}"
echo ""

# 显示备份信息
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  备份完成！${NC}"
echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}备份文件: ${YELLOW}$BACKUP_FILE${NC}"
echo -e "${GREEN}文件大小: ${YELLOW}$BACKUP_SIZE${NC}"
echo ""

# 清理旧备份（保留最近 7 天）
echo -e "${YELLOW}清理 7 天前的旧备份...${NC}"
find "$BACKUP_DIR" -name "etcd-backup-*.db" -type f -mtime +7 -delete 2>/dev/null || true

# 显示所有备份
echo -e "${GREEN}现有备份列表:${NC}"
ls -lh "$BACKUP_DIR"/etcd-backup-*.db 2>/dev/null || echo "无备份文件"
echo ""

echo -e "${YELLOW}提示: 建议将备份文件复制到其他机器或云存储${NC}"
echo ""
