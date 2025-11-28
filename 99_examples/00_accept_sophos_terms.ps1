# Find the exact Sophos offer
az vm image list --publisher sophos --all --output table

# Accept the terms (adjust publisher/offer/sku based on your Bicep)
az vm image terms accept  --publisher sophos --offer sophos-xg --plan byol
