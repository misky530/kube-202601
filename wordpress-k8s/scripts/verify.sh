#!/bin/bash

##############################################
# 验证脚本 - 检查集群和应用状态
##############################################

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  集群状态验证${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# 检查节点状态
echo -e "${YELLOW}[1] 节点状态:${NC}"
kubectl get nodes -o wide
echo ""

# 检查 etcd 状态
echo -e "${YELLOW}[2] etcd 状态:${NC}"
sudo systemctl status etcd --no-pager | grep Active
sudo ss -tulnp | grep 2379 || echo "etcd 端口未监听"
echo ""

# 检查系统组件
echo -e "${YELLOW}[3] 系统组件 (kube-system):${NC}"
kubectl get pods -n kube-system
echo ""

# 检查 WordPress 应用
echo -e "${YELLOW}[4] WordPress 应用 (wordpress-v2):${NC}"
if kubectl get namespace wordpress-v2 &>/dev/null; then
    kubectl get all,pvc,ingress -n wordpress-v2
else
    echo -e "${YELLOW}wordpress-v2 命名空间不存在${NC}"
fi
echo ""

# 检查 Ingress Controller
echo -e "${YELLOW}[5] Ingress Controller:${NC}"
kubectl get pods -n ingress-nginx
echo ""
kubectl get svc -n ingress-nginx
echo ""

# 显示访问信息
echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  访问信息${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""
if kubectl get ingress -n wordpress-v2 &>/dev/null; then
    echo -e "${GREEN}WordPress 访问地址:${NC}"
    echo -e "  ${YELLOW}http://wordpress.local:30028${NC}"
    echo ""
    echo -e "${GREEN}配置 hosts (如果尚未配置):${NC}"
    echo -e "  ${YELLOW}sudo bash -c 'echo \"192.168.226.131 wordpress.local\" >> /etc/hosts'${NC}"
    echo ""
fi

# 快速诊断
echo -e "${YELLOW}[6] 快速诊断:${NC}"
ISSUES=0

# 检查节点是否 Ready
NOT_READY=$(kubectl get nodes --no-headers | grep -v " Ready" | wc -l)
if [ $NOT_READY -gt 0 ]; then
    echo -e "${RED}✗ 有 $NOT_READY 个节点未就绪${NC}"
    ISSUES=$((ISSUES+1))
else
    echo -e "${GREEN}✓ 所有节点就绪${NC}"
fi

# 检查 WordPress Pods
if kubectl get namespace wordpress-v2 &>/dev/null; then
    WP_PODS=$(kubectl get pods -n wordpress-v2 -l app=wordpress --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [ $WP_PODS -gt 0 ]; then
        echo -e "${GREEN}✓ WordPress 有 $WP_PODS 个 Pod 运行中${NC}"
    else
        echo -e "${RED}✗ WordPress Pods 未运行${NC}"
        ISSUES=$((ISSUES+1))
    fi

    # 检查 MySQL Pods
    MYSQL_PODS=$(kubectl get pods -n wordpress-v2 -l app=mysql --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [ $MYSQL_PODS -gt 0 ]; then
        echo -e "${GREEN}✓ MySQL Pod 运行中${NC}"
    else
        echo -e "${RED}✗ MySQL Pod 未运行${NC}"
        ISSUES=$((ISSUES+1))
    fi
fi

echo ""
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ 所有检查通过！${NC}"
else
    echo -e "${YELLOW}发现 $ISSUES 个问题，请检查详细信息${NC}"
fi
echo ""
