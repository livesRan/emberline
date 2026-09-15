#!/usr/bin/env bash
# 自动关闭 Emberline 测试沙箱环境下的所有非生产虚拟机
set -eo pipefail

RESOURCE_GROUP="rg-emberline-prod"
TAG_FILTER="Environment=Testing"

echo "=========================================================="
echo " Starting Nightly Shutdown Runbook at $(date)"
echo "=========================================================="

# 1. 登录 Azure CLI (利用系统托管标识登录运维节点)
az login --identity

# 2. 查询拥有 Testing 标签的正在运行的虚拟机
VM_LIST=$(az vm list --resource-group "$RESOURCE_GROUP" --show-details \
  --query "[?tags.Environment=='Testing' && powerState=='VM running'].name" -o tsv)

if [ -z "$VM_LIST" ]; then
    echo "[INFO] No running testing VMs found. Exiting gracefully."
    exit 0
fi

# 3. 循环关闭目标虚拟机
for VM in $VM_LIST; do
    echo "[ACTION] Stopping and deallocating VM: $VM ..."
    az vm deallocate --resource-group "$RESOURCE_GROUP" --name "$VM" --no-wait
    echo "[SUCCESS] Stop command sent to $VM successfully."
done

echo "=========================================================="
echo " Runbook Completed successfully."
echo "=========================================================="
