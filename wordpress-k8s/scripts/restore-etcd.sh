#!/bin/bash

##############################################
# etcd 恢复脚本
# 功能：从备份恢复 etcd 数据
# 警告：此操作会覆盖当前 etcd 数据！
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
ETCD_DATA_DIR="/var/lib/etcd"

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  etcd 恢复工具${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# 检查是否在 master 节点
if [ ! -f "/etc/etcd.env" ]; then
    echo -e "${RED}错误: 此脚本必须在 k8s-master 节点上运行${NC}"
    exit 1
fi

# 检查 etcdctl 是否可用
if ! command -v etcdctl &> /dev/null; then
    echo -e "${RED}错误: etcdctl 命令未找到${NC}"
    exit 1
fi

# 列出可用备份
echo -e "${GREEN}可用的备份文件:${NC}"
if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR/etcd-backup-*.db 2>/dev/null)" ]; then
    echo -e "${RED}错误: 未找到备份文件${NC}"
    exit 1
fi

ls -lh "$BACKUP_DIR"/etcd-backup-*.db
echo ""

# 选择备份文件
read -p "请输入要恢复的备份文件名 (或输入 'latest' 使用最新备份): " BACKUP_NAME
echo ""

if [ "$BACKUP_NAME" = "latest" ]; then
    BACKUP_FILE=$(ls -t "$BACKUP_DIR"/etcd-backup-*.db | head -1)
    echo -e "${YELLOW}使用最新备份: $BACKUP_FILE${NC}"
else
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_NAME"
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}错误: 备份文件不存在: $BACKUP_FILE${NC}"
    exit 1
fi

echo ""
echo -e "${RED}警告: 此操作将覆盖当前 etcd 数据！${NC}"
echo -e "${RED}所有未备份的 Kubernetes 配置将丢失！${NC}"
echo ""
read -p "确认继续? 请输入 'YES' 以确认: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo -e "${YELLOW}取消恢复操作${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}[1/5] 停止 etcd 服务...${NC}"
sudo systemctl stop etcd
echo -e "${GREEN}✓ etcd 已停止${NC}"
echo ""

echo -e "${YELLOW}[2/5] 备份当前 etcd 数据...${NC}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
if [ -d "$ETCD_DATA_DIR" ]; then
    sudo mv "$ETCD_DATA_DIR" "${ETCD_DATA_DIR}.backup.$TIMESTAMP"
    echo -e "${GREEN}✓ 当前数据已备份到: ${ETCD_DATA_DIR}.backup.$TIMESTAMP${NC}"
else
    echo -e "${YELLOW}  etcd 数据目录不存在，跳过备份${NC}"
fi
echo ""

echo -e "${YELLOW}[3/5] 从快照恢复 etcd...${NC}"
sudo ETCDCTL_API=3 etcdctl snapshot restore "$BACKUP_FILE" \
  --data-dir="$ETCD_DATA_DIR" \
  --name=k8s-master \
  --initial-cluster=k8s-master=https://192.168.226.131:2380 \
  --initial-advertise-peer-urls=https://192.168.226.131:2380

echo -e "${GREEN}✓ 数据恢复完成${NC}"
echo ""

echo -e "${YELLOW}[4/5] 修改 etcd 配置...${NC}"
# 将 ETCD_INITIAL_CLUSTER_STATE 设置为 existing（因为是从备份恢复）
sudo cp /etc/etcd.env /etc/etcd.env.backup.$TIMESTAMP
sudo sed -i 's/ETCD_INITIAL_CLUSTER_STATE=new/ETCD_INITIAL_CLUSTER_STATE=existing/g' /etc/etcd.env
echo -e "${GREEN}✓ 配置已更新${NC}"
echo ""

echo -e "${YELLOW}[5/5] 启动 etcd 服务...${NC}"
sudo systemctl daemon-reload
sudo systemctl start etcd
sleep 5

# 检查 etcd 状态
if sudo systemctl is-active --quiet etcd; then
    echo -e "${GREEN}✓ etcd 服务已启动${NC}"
else
    echo -e "${RED}错误: etcd 启动失败${NC}"
    echo -e "${YELLOW}查看日志: sudo journalctl -xeu etcd --no-pager | tail -50${NC}"
    exit 1
fi
echo ""

# 重启 kubelet
echo -e "${YELLOW}重启 kubelet...${NC}"
sudo systemctl restart kubelet
sleep 10
echo -e "${GREEN}✓ kubelet 已重启${NC}"
echo ""

# 显示恢复结果
echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  恢复完成！${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""
echo -e "${GREEN}验证集群状态:${NC}"
kubectl get nodes
echo ""
kubectl get pods -n kube-system
echo ""

echo -e "${YELLOW}注意: 如果部分 Pod 未运行，请等待几分钟后再检查${NC}"
echo ""
