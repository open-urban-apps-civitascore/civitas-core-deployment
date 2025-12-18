# Kafka

Asynchronous central message broker for interservice communication

## Integration Contract

### Connection Details

**Bootstrap Server:**
- Service: `kafka-cluster-kafka-bootstrap.<namespace>.svc.cluster.local:9092`
- For same-namespace access: `kafka-cluster-kafka-bootstrap:9092`
- Default namespace suffix: `-kafka` (e.g., `civitas-kafka`)

**Protocol:**
- Plain connection (no TLS) - ⚠️ **Production deployments should enable TLS**
- Default port: `9092`

### Authentication & Authorization

**Current Setup:**
- ⚠️ **No authentication enabled** - suitable for testing only
- All services within the cluster can access Kafka
- Relies on Kubernetes network policies for isolation

### Monitoring & Management

**Kafka UI:**
- Accessible via ingress (if enabled)
- Default subdomain: `kafka-ui.<domain>`
- Features: topic browsing, message inspection, consumer groups

**Metrics:**
- Strimzi operator exposes Prometheus metrics
- Monitor: broker health, topic lag, throughput


### Testing

**From within a pod:**

```bash
# Create a test pod
kubectl run kafka-test -n dev -it --rm --restart=Never \
  --image=quay.io/strimzi/kafka:latest-kafka-3.6.0 -- bash

# Inside the pod - produce a message
bin/kafka-console-producer.sh \
  --bootstrap-server kafka-cluster-kafka-bootstrap:9092 \
  --topic test-topic

# Consume messages
bin/kafka-console-consumer.sh \
  --bootstrap-server kafka-cluster-kafka-bootstrap:9092 \
  --topic test-topic \
  --from-beginning
```

### Limitations & Known Issues

- **TLS:** Currently disabled - must be configured for production
- **Authentication:** Not enabled - cluster-internal services only
- **Multi-tenancy:** No namespace isolation - all services share the same Kafka cluster
- **Backup:** No automated backup configured - consider velero or similar

### Troubleshooting

**Connection issues:**
1. Verify namespace and service name
2. Check network policies
3. Verify pod can resolve DNS: `nslookup kafka-cluster-kafka-bootstrap`

**Performance:**
1. Monitor consumer lag in Kafka UI
2. Adjust partition count for parallelism
3. Review resource limits for brokers

**For operators:**
- Broker logs: `kubectl logs -n <namespace> kafka-cluster-kafka-<n>`
- Operator logs: `kubectl logs -n <namespace> -l name=strimzi-cluster-operator`
