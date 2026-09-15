#!/usr/bin/env bash
# 动态伸缩核心 MySQL Flexible Server 配置规格
set -eo pipefail

RESOURCE_GROUP="rg-emberline-prod"
SERVER_NAME="emberline-mysql-prod"
TARGET_SKU="Standard_D16ds_v4"  # 扩展目标规格
# TARGET_SKU="Standard_D8ds_v4"   # 还原常态规格 (结算后运行)

echo "[ACTION] Upgrading PaaS Database Server spec to $TARGET_SKU..."

az login --identity

# 在线对 MySQL 灵活服务器进行计算规格扩容
az mysql flexible-server update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$SERVER_NAME" \
  --sku-name "$TARGET_SKU"

echo "[SUCCESS] PaaS Database scaling task completed."
