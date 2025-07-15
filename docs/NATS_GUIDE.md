# NATS + JetStream Messaging Guide

**Date**: 2025-07-15
**Status**: Active

## Overview

This guide covers the NATS messaging system with JetStream persistence deployed in homelab-foundations, designed for high-performance IoT data ingestion and stream processing.

## Architecture

### Deployment Configuration
- **Single-node deployment**: 1 NATS pod with 3 containers
- **Memory allocation**: 512Mi container limit
- **JetStream memory**: 1Gi for fast message access
- **JetStream storage**: 10Gi persistent file storage via Longhorn
- **Replicas**: 1 (appropriate for homelab, no quorum required)

### Container Structure
- **nats**: Main NATS server process
- **reloader**: Configuration hot-reload capability
- **prom-exporter**: Prometheus metrics exporter

### Storage Architecture
- **Memory Store**: 1Gi for high-speed message buffering
- **File Store**: 10Gi persistent storage for message durability
- **Storage Directory**: `/data/jetstream` with proper permissions (fsGroup: 1000)
- **Backup**: Longhorn-managed persistent volume with snapshots

## Access Information

### Connection Details
- **NATS Protocol**: nats://nats:4222 (internal cluster)
- **External Access**: nats://10.0.0.248:4222 (if LoadBalancer configured)
- **Monitoring**: http://10.0.0.248:8222/varz (metrics endpoint)
- **Health Check**: http://10.0.0.248:8222/healthz

### NATS Box Utility
```bash
# Get NATS box pod name
NATS_BOX=$(kubectl get pods -n nats -l app=nats-box -o jsonpath='{.items[0].metadata.name}')

# Use NATS box for all CLI operations
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 [command]
```

## Getting Started Examples

### Basic Server Information
```bash
# Check server status
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 server ping

# View server configuration
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 server info
```

### Stream Management

#### Create Streams
```bash
# IoT sensor data stream
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 stream add iot-sensors \
  --subjects "sensors.>" \
  --storage file \
  --retention limits \
  --max-age=24h \
  --max-msgs=-1 \
  --replicas=1 \
  --defaults

# Application logs stream
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 stream add app-logs \
  --subjects "logs.>" \
  --storage file \
  --retention limits \
  --max-age=7d \
  --max-bytes=1GB \
  --replicas=1 \
  --defaults

# Real-time events stream (memory-based)
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 stream add events \
  --subjects "events.>" \
  --storage memory \
  --retention limits \
  --max-age=1h \
  --replicas=1 \
  --defaults
```

#### List and Inspect Streams
```bash
# List all streams
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 stream ls

# Get detailed stream information
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 stream info iot-sensors

# View stream subjects
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 stream subjects iot-sensors
```

### Publishing Messages

#### IoT Sensor Data Examples
```bash
# Temperature sensor data
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 pub sensors.temperature.room1 '{"value": 22.5, "unit": "C", "timestamp": "2025-07-15T10:30:00Z"}'

# Humidity sensor data
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 pub sensors.humidity.room1 '{"value": 45.2, "unit": "%", "timestamp": "2025-07-15T10:30:00Z"}'

# Motion sensor data
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 pub sensors.motion.door1 '{"detected": true, "timestamp": "2025-07-15T10:30:00Z"}'

# Batch publish multiple readings
for i in {1..10}; do
  kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 pub sensors.temperature.room1 "{\"value\": $((20 + i)), \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
done
```

### Subscribing to Messages

#### Real-time Subscriptions
```bash
# Subscribe to all sensor data
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 sub sensors.>

# Subscribe to specific sensor type
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 sub sensors.temperature.>

# Subscribe with queue group (load balancing)
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 sub sensors.> --queue processors
```

#### Consumer Management
```bash
# Create durable consumer for processing
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 consumer add iot-sensors processor \
  --filter sensors.temperature.> \
  --ack explicit \
  --pull \
  --deliver all \
  --max-deliver 3 \
  --defaults

# List consumers
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 consumer ls iot-sensors

# Get consumer info
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 consumer info iot-sensors processor
```

## Advanced Features

### Message Replay and Time Travel
```bash
# Replay messages from specific time
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 consumer add iot-sensors replay \
  --filter sensors.> \
  --deliver by_start_time \
  --opt-start-time "2025-07-15T10:00:00Z" \
  --defaults

# Replay last N messages
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 consumer add iot-sensors last-100 \
  --filter sensors.> \
  --deliver last_per_subject \
  --defaults
```

### Stream Backup and Recovery
```bash
# Backup stream data
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 stream backup iot-sensors /tmp/backup.tar.gz

# Restore stream data
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 stream restore /tmp/backup.tar.gz
```

### Performance Monitoring
```bash
# Stream statistics
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 stream report

# Consumer performance
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 consumer report iot-sensors

# Server metrics
curl -s http://10.0.0.248:8222/varz | jq '.mem, .cpu, .connections'
```

## Integration Examples

### IoT Data Pipeline
```bash
# 1. Create sensor data stream
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 stream add sensors \
  --subjects "iot.>" --storage file --retention limits --max-age=30d --replicas=1 --defaults

# 2. Create processing consumer
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 consumer add sensors analytics \
  --filter iot.sensors.> --ack explicit --pull --deliver all --defaults

# 3. Simulate IoT device publishing
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 pub iot.sensors.temp.device001 \
  '{"device_id":"device001","sensor":"temperature","value":23.4,"unit":"celsius","location":"living_room","timestamp":"2025-07-15T10:30:00Z"}'
```

### Integration with Trino Analytics
```bash
# Publish structured data for analytics
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 pub analytics.events.user_action \
  '{"user_id":"user123","action":"login","timestamp":"2025-07-15T10:30:00Z","metadata":{"ip":"192.168.1.100","device":"mobile"}}'

# Stream can be consumed by applications that write to Iceberg tables via Trino
```

## Monitoring and Troubleshooting

### Health Checks
```bash
# Server health
curl -s http://10.0.0.248:8222/healthz

# JetStream health
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 server check jetstream

# Connection status
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 server list
```

### Common Issues

1. **Permission Denied on /data**: Fixed with fsGroup: 1000 in pod security context
2. **Stream Creation Fails**: Check JetStream is enabled and storage available
3. **Consumer Lag**: Monitor consumer performance and adjust processing

### Useful Monitoring Queries
```bash
# Check storage usage
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 server info | grep -A 5 "JetStream"

# Monitor message rates
watch 'kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 stream info iot-sensors | grep Messages'
```

## Production Considerations

### Scaling
- **Current**: Single-node deployment suitable for homelab
- **Future**: Can scale to clustered deployment with multiple replicas
- **Performance**: Handles thousands of messages/second in current configuration

### Backup Strategy
- **Longhorn snapshots**: Automatic volume snapshots
- **Stream backups**: Manual backup/restore via NATS CLI
- **Configuration**: GitOps ensures reproducible deployments

### Security
- **Network**: Internal cluster communication only
- **Authentication**: None configured (suitable for homelab)
- **Authorization**: Subject-based permissions can be added

## Next Steps

1. **Set up IoT devices** to publish to NATS streams
2. **Create data processing** consumers for analytics
3. **Integrate with Trino** for stream-to-analytics pipelines
4. **Add monitoring dashboards** for NATS metrics in Grafana
5. **Implement backup automation** for critical streams

For more advanced configurations and troubleshooting, see the [Operational Runbook](OPERATIONAL_RUNBOOK.md).
