#!/bin/bash

##############################################
# WordPress on Kubernetes - 清理脚本
# 功能：删除所有部署的资源（保留 PVC 数据）
##############################################

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MANIFESTS_DIR="$PROJECT_DIR/manifests"

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  WordPress on Kubernetes - 清理资源${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# 检查 kubectl 是否可用
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}错误: kubectl 命令未找到${NC}"
    exit 1
fi

# 显示当前资源
echo -e "${YELLOW}当前资源状态:${NC}"
kubectl get all,pvc,ingress -n wordpress-v2 2>/dev/null || echo "命名空间不存在或无资源"
echo ""

# 确认删除
read -p "是否删除所有资源? (保留 PVC 数据) [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}取消删除操作${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}[1/3] 删除 WordPress 资源...${NC}"
kubectl delete -f "$MANIFESTS_DIR/wordpress/ingress.yaml" --ignore-not-found=true
kubectl delete -f "$MANIFESTS_DIR/wordpress/service.yaml" --ignore-not-found=true
kubectl delete -f "$MANIFESTS_DIR/wordpress/deployment.yaml" --ignore-not-found=true
echo -e "${GREEN}✓ WordPress 资源已删除${NC}"
echo ""

echo -e "${YELLOW}[2/3] 删除 MySQL 资源...${NC}"
kubectl delete -f "$MANIFESTS_DIR/mysql/service.yaml" --ignore-not-found=true
kubectl delete -f "$MANIFESTS_DIR/mysql/deployment.yaml" --ignore-not-found=true
kubectl delete -f "$MANIFESTS_DIR/mysql/secret.yaml" --ignore-not-found=true
echo -e "${GREEN}✓ MySQL 资源已删除${NC}"
echo ""

echo -e "${YELLOW}[3/3] 保留 PVC (数据将被保留)${NC}"
echo -e "${BLUE}如果需要删除 PVC 和数据，请手动执行:${NC}"
echo -e "  ${YELLOW}kubectl delete -f $MANIFESTS_DIR/wordpress/pvc.yaml${NC}"
echo -e "  ${YELLOW}kubectl delete -f $MANIFESTS_DIR/mysql/pvc.yaml${NC}"
echo ""

# 显示剩余资源
echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  清理完成！${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""
echo -e "${GREEN}剩余资源（应该只有 PVC）:${NC}"
kubectl get all,pvc,ingress -n wordpress-v2 2>/dev/null || echo "无资源"
echo ""

# 询问是否删除命名空间
read -p "是否删除命名空间和所有 PVC? (将删除所有数据) [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}删除命名空间和所有数据...${NC}"
    kubectl delete namespace wordpress-v2 --ignore-not-found=true
    echo -e "${GREEN}✓ 所有资源已完全删除${NC}"
else
    echo -e "${YELLOW}保留命名空间和 PVC 数据${NC}"
fi
echo ""
