# Alertmanager

Receives alerts from Prometheus and handles deduplication, grouping, and
routing to notification channels. Delivers alerts via Telegram to ensure
operational issues surface promptly without duplicate noise. Notification
credentials are retrieved from Vault at runtime.

## Dependencies

- **Prometheus** -- the sole alert source feeding Alertmanager
