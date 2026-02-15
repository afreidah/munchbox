# Alertmanager

Receives alerts from Prometheus and handles deduplication, grouping, and
routing to notification channels. Delivers alerts via Telegram to ensure
operational issues surface promptly without duplicate noise. Notification
credentials are retrieved from Vault at runtime.

## Architecture

Runs as a system job on both ingress nodes. The two instances form a gossip
cluster via port 9094, using `--cluster.peer=alertmanager.service.consul:9094`
for peer discovery. Clustering ensures that when both Prometheus instances
fire the same alert, only one notification is sent to Telegram.

## Dependencies

- **Prometheus** -- the sole alert source feeding Alertmanager
