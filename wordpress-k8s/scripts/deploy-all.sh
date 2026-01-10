#!/bin/bash

##############################################
# WordPress on Kubernetes - 自动化部署脚本
# 功能：一键部署所有 Kubernetes 资源
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
echo -e "${BLUE}  WordPress on Kubernetes - 自动化部署${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# 检查 kubectl 是否可用
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}错误: kubectl 命令未找到${NC}"
    exit 1
fi

# 检查集群连接
echo -e "${YELLOW}[1/7] 检查集群连接...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}错误: 无法连接到 Kubernetes 集群${NC}"
    echo -e "${RED}请检查集群状态: kubectl get nodes${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 集群连接正常${NC}"
echo ""

# 显示集群信息
echo -e "${YELLOW}[2/7] 集群信息:${NC}"
kubectl get nodes
echo ""

# 创建命名空间
echo -e "${YELLOW}[3/7] 创建命名空间...${NC}"
kubectl apply -f "$MANIFESTS_DIR/namespace.yaml"
echo -e "${GREEN}✓ 命名空间创建完成${NC}"
echo ""

# 部署 MySQL
echo -e "${YELLOW}[4/7] 部署 MySQL...${NC}"
echo "  - 创建 Secret..."
kubectl apply -f "$MANIFESTS_DIR/mysql/secret.yaml"
echo "  - 创建 PVC..."
kubectl apply -f "$MANIFESTS_DIR/mysql/pvc.yaml"
echo "  - 创建 Deployment..."
kubectl apply -f "$MANIFESTS_DIR/mysql/deployment.yaml"
echo "  - 创建 Service..."
kubectl apply -f "$MANIFESTS_DIR/mysql/service.yaml"
echo -e "${GREEN}✓ MySQL 部署完成${NC}"
echo ""

# 等待 MySQL 就绪
echo -e "${YELLOW}[5/7] 等待 MySQL 就绪...${NC}"
kubectl wait --for=condition=ready pod -l app=mysql -n wordpress-v2 --timeout=300s
echo -e "${GREEN}✓ MySQL 已就绪${NC}"
echo ""

# 部署 WordPress
echo -e "${YELLOW}[6/7] 部署 WordPress...${NC}"
echo "  - 创建 PVC..."
kubectl apply -f "$MANIFESTS_DIR/wordpress/pvc.yaml"
echo "  - 创建 Deployment..."
kubectl apply -f "$MANIFESTS_DIR/wordpress/deployment.yaml"
echo "  - 创建 Service..."
kubectl apply -f "$MANIFESTS_DIR/wordpress/service.yaml"
echo "  - 创建 Ingress..."
kubectl apply -f "$MANIFESTS_DIR/wordpress/ingress.yaml"
echo -e "${GREEN}✓ WordPress 部署完成${NC}"
echo ""

# 等待 WordPress 就绪
echo -e "${YELLOW}[7/7] 等待 WordPress 就绪...${NC}"
kubectl wait --for=condition=ready pod -l app=wordpress -n wordpress-v2 --timeout=300s
echo -e "${GREEN}✓ WordPress 已就绪${NC}"
echo ""

# 显示部署结果
echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  部署完成！${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""
echo -e "${GREEN}查看所有资源:${NC}"
kubectl get all,pvc,ingress -n wordpress-v2
echo ""

echo -e "${GREEN}访问 WordPress:${NC}"
echo -e "  URL: ${YELLOW}http://wordpress.local:30028${NC}"
echo ""
echo -e "${GREEN}配置 hosts 文件:${NC}"
echo -e "  ${YELLOW}sudo bash -c 'echo \"192.168.226.131 wordpress.local\" >> /etc/hosts'${NC}"
echo -e "  ${YELLOW}sudo bash -c 'echo \"192.168.226.132 wordpress.local\" >> /etc/hosts'${NC}"
echo -e "  ${YELLOW}sudo bash -c 'echo \"192.168.226.133 wordpress.local\" >> /etc/hosts'${NC}"
echo ""

echo -e "${GREEN}验证部署:${NC}"
echo -e "  ${YELLOW}kubectl get pods -n wordpress-v2${NC}"
echo -e "  ${YELLOW}kubectl logs -f deployment/wordpress -n wordpress-v2${NC}"
echo ""
