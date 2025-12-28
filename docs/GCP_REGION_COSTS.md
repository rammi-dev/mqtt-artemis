# GCP Region Cost Comparison for GKE

## TL;DR - Cheapest Regions

**For maximum cost savings, use US regions:**
1. 🏆 **us-central1** (Iowa) - CHEAPEST
2. **us-east1** (South Carolina)
3. **us-west1** (Oregon)

**If you must stay in Europe:**
- **europe-west1** (Belgium) - Cheapest in EU

## Detailed Cost Comparison

### e2-standard-4 (4 vCPU, 16 GB RAM) with Spot VMs

| Region | Location | Monthly Cost* | vs Cheapest |
|--------|----------|---------------|-------------|
| **us-central1** | Iowa | **$40-50** | Baseline |
| us-east1 | South Carolina | $40-50 | +0% |
| us-west1 | Oregon | $40-50 | +0% |
| europe-west1 | Belgium | $48-60 | +15-20% |
| europe-west4 | Netherlands | $48-60 | +15-20% |
| **europe-central2** | Warsaw | **$50-65** | **+20-25%** |
| europe-west3 | Frankfurt | $52-68 | +25-30% |
| europe-north1 | Finland | $54-70 | +30-35% |
| asia-east1 | Taiwan | $48-62 | +15-25% |

*Estimated monthly cost with Spot VMs, autoscaling 1-3 nodes, 100GB disk

### e2-standard-2 (2 vCPU, 8 GB RAM) with Spot VMs

| Region | Location | Monthly Cost* | vs Cheapest |
|--------|----------|---------------|-------------|
| **us-central1** | Iowa | **$20-30** | Baseline |
| us-east1 | South Carolina | $20-30 | +0% |
| us-west1 | Oregon | $20-30 | +0% |
| europe-west1 | Belgium | $24-36 | +15-20% |
| europe-west4 | Netherlands | $24-36 | +15-20% |
| **europe-central2** | Warsaw | **$25-40** | **+20-25%** |

*Estimated monthly cost with Spot VMs, autoscaling 1-2 nodes, 50GB disk

## Annual Savings

### Balanced Setup (e2-standard-4)
- **us-central1**: ~$480-600/year
- **europe-central2**: ~$600-780/year
- **Savings**: ~$120-180/year (20-25%)

### Minimal Setup (e2-standard-2)
- **us-central1**: ~$240-360/year
- **europe-central2**: ~$300-480/year
- **Savings**: ~$60-120/year (20-25%)

## Other Cost Factors

### Network Egress
US regions also have cheaper network egress:
- **us-central1**: $0.12/GB (to internet)
- **europe-central2**: $0.12/GB (to internet)
- Similar, but US regions have better peering

### Latency Considerations

If your users/services are in:
- **North America**: Use us-central1, us-east1, or us-west1
- **Europe**: Use europe-west1 (Belgium) - best price/latency balance
- **Asia**: Use asia-east1 (Taiwan)

**Latency from europe-central2 (Warsaw):**
- To Western Europe: ~20-30ms
- To US East Coast: ~100-120ms
- To US West Coast: ~150-180ms

**Latency from us-central1 (Iowa):**
- To US East Coast: ~30-40ms
- To US West Coast: ~50-60ms
- To Western Europe: ~100-120ms

## Recommendations

### For Development/Testing
✅ **Use us-central1** (Iowa)
- Cheapest option
- Latency doesn't matter for dev/test
- **Savings: 20-25% vs europe-central2**

### For Production (Global Users)
✅ **Use us-central1** (Iowa) if most users in Americas
✅ **Use europe-west1** (Belgium) if most users in Europe
- Best price/performance in EU
- Only ~15% more than US regions
- Much cheaper than europe-central2

### For Production (EU Data Residency Required)
✅ **Use europe-west1** (Belgium)
- Cheapest EU option
- Good connectivity
- GDPR compliant

❌ **Avoid europe-central2** unless you specifically need Warsaw location
- 20-25% more expensive than us-central1
- 15-20% more expensive than europe-west1

## How to Change Region

Edit `gke-infrastructure/gke/terraform.tfvars`:

```hcl
# For maximum cost savings (RECOMMENDED)
region = "us-central1"
zone   = "us-central1-a"

# OR for cheapest EU option
region = "europe-west1"
zone   = "europe-west1-b"
```

Available zones:
- **us-central1**: a, b, c, f
- **us-east1**: b, c, d
- **us-west1**: a, b, c
- **europe-west1**: b, c, d
- **europe-west4**: a, b, c

## Current Configuration

Your current setup uses:
- ❌ **europe-central2-b** (Warsaw)
- 💰 **Cost**: ~20-25% more expensive than us-central1

**Recommended change:**
- ✅ **us-central1-a** (Iowa)
- 💰 **Savings**: ~$120-180/year for balanced setup

## Summary

| Setup | Current (europe-central2) | Recommended (us-central1) | Annual Savings |
|-------|---------------------------|---------------------------|----------------|
| Minimal (e2-standard-2) | $300-480/year | $240-360/year | $60-120/year |
| Balanced (e2-standard-4) | $600-780/year | $480-600/year | $120-180/year |
| Production (HA) | $2400-3120/year | $1920-2400/year | $480-720/year |

**Bottom line**: Switch to **us-central1** to save 20-25% on GKE costs! 💰
