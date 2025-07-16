# Pi-hole DNS Server Guide

**Version**: 1.0
**Date**: 2025-07-16
**Author**: Community Contributors
**Status**: Active

## Overview

Pi-hole provides local DNS resolution for `.homelab.local` domains in the homelab-foundations cluster. It acts as both a DNS server and ad-blocker, enabling seamless access to all cluster services via hostnames instead of IP addresses.

## Architecture

### Deployment Details
- **Namespace**: `dns-system`
- **Image**: `pihole/pihole:2024.07.0`
- **Management**: Flux GitOps
- **LoadBalancer**: MetalLB provides external IP access
- **Storage**: Longhorn persistent volumes for configuration

### Network Configuration
- **DNS Service**: `10.0.0.249:53` (TCP/UDP)
- **Web Interface**: `http://10.0.0.249:80/admin`
- **Ingress**: `http://pihole.homelab.local/admin`
- **Upstream DNS**: Cloudflare (1.1.1.1, 1.0.0.1)

## Access Methods

### Web Interface
- **Direct IP**: http://10.0.0.249/admin
- **Hostname**: http://pihole.homelab.local/admin (requires Pi-hole as DNS)
- **Credentials**: admin / homelab123

### DNS Service
- **Primary DNS**: Use as secondary DNS server (recommended)
- **Direct DNS**: Configure clients to use 10.0.0.249:53

## DNS Resolution

### Homelab Services
All `.homelab.local` domains resolve to HAProxy ingress (10.0.0.245):

```
grafana.homelab.local        → 10.0.0.245
clickhouse.homelab.local     → 10.0.0.245
trino.homelab.local          → 10.0.0.245
iceberg.homelab.local        → 10.0.0.245
longhorn.homelab.local       → 10.0.0.245
nats.homelab.local           → 10.0.0.245
minio-console.homelab.local  → 10.0.0.245
minio.homelab.local          → 10.0.0.245
pihole.homelab.local         → 10.0.0.249
```

### External Domains
All other domains are forwarded to Cloudflare DNS (1.1.1.1, 1.0.0.1).

## Client Configuration

### macOS DNS Setup
Add Pi-hole as secondary DNS server:

**System Preferences Method**:
1. System Preferences → Network
2. Select connection → Advanced → DNS
3. Add DNS servers:
   - Primary: 1.1.1.1
   - Secondary: 10.0.0.249
4. Apply

**Command Line Method**:
```bash
# Wi-Fi
sudo networksetup -setdnsservers "Wi-Fi" 1.1.1.1 10.0.0.249

# Ethernet
sudo networksetup -setdnsservers "Ethernet" 1.1.1.1 10.0.0.249
```

### Linux DNS Setup
Edit `/etc/systemd/resolved.conf`:
```ini
[Resolve]
DNS=1.1.1.1 10.0.0.249
Domains=~homelab.local
```

Then restart: `sudo systemctl restart systemd-resolved`

### Windows DNS Setup
1. Network Settings → Change adapter options
2. Right-click connection → Properties
3. Select IPv4 → Properties
4. Use these DNS servers:
   - Preferred: 1.1.1.1
   - Alternate: 10.0.0.249

## Configuration Files

### Deployment
- **Main Config**: `clusters/um890/dns/pihole-deployment.yaml`
- **Services**: `clusters/um890/dns/pihole-services.yaml`
- **DNS Entries**: `clusters/um890/dns/pihole-configmap.yaml`
- **Ingress**: `clusters/um890/dns/pihole-ingress.yaml`
- **Kustomization**: `clusters/um890/dns/kustomization.yaml`

### Custom DNS Entries
DNS entries are managed via ConfigMap in `pihole-configmap.yaml`:

```yaml
data:
  02-homelab.conf: |
    address=/grafana.homelab.local/10.0.0.245
    address=/clickhouse.homelab.local/10.0.0.245
    # ... additional entries
```

## Management

### Adding DNS Entries
1. Edit `clusters/um890/dns/pihole-configmap.yaml`
2. Add new `address=/hostname.homelab.local/IP` entry
3. Commit and push changes
4. Flux will automatically update Pi-hole configuration

### Web Interface Management
Access http://pihole.homelab.local/admin to:
- View DNS query logs
- Manage blocklists
- Configure upstream DNS servers
- Monitor system performance
- Add manual DNS entries (temporary)

### Monitoring
```bash
# Check Pi-hole pods
kubectl get pods -n dns-system

# Check DNS services
kubectl get svc -n dns-system

# Test DNS resolution
nslookup grafana.homelab.local 10.0.0.249
```

## Troubleshooting

### DNS Not Resolving
```bash
# Test Pi-hole directly
nslookup grafana.homelab.local 10.0.0.249

# Check Pi-hole logs
kubectl logs -n dns-system deployment/pihole

# Verify services have external IPs
kubectl get svc -n dns-system
```

### Web Interface Issues
```bash
# Check ingress status
kubectl get ingress -n dns-system

# Test direct IP access
curl -I http://10.0.0.249/admin

# Check HAProxy ingress
kubectl get svc -n haproxy-controller
```

### Configuration Updates
```bash
# Force configuration reload
kubectl rollout restart deployment/pihole -n dns-system

# Check ConfigMap
kubectl get configmap pihole-custom-dns -n dns-system -o yaml
```

## Security Considerations

### Network Security
- Pi-hole only accessible from local network (10.0.0.0/24)
- No external DNS queries logged or forwarded
- Upstream DNS uses secure Cloudflare servers

### Access Control
- Web interface password protected (homelab123)
- DNS service requires network access to cluster
- Configuration managed via GitOps (version controlled)

## Performance

### Resource Usage
- **CPU**: 100m requests, 500m limits
- **Memory**: 128Mi requests, 512Mi limits
- **Storage**: 1.5Gi total (Pi-hole data + dnsmasq config)

### Query Performance
- Local `.homelab.local` queries: ~1ms response time
- External queries: Forwarded to Cloudflare (~10-20ms)
- Query caching enabled for improved performance

Pi-hole provides reliable, fast DNS resolution for your homelab services while maintaining security and performance standards suitable for production use.
