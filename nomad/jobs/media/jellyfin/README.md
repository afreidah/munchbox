# Jellyfin

Primary media streaming platform for movies, TV shows, and music. Runs on
the GPU node for NVIDIA hardware-accelerated transcoding. Uses its own
authentication rather than the cluster-wide OAuth2 proxy, allowing direct
client app access without SSO complications.

## Dependencies

- **ErsatzTV** -- generates virtual live TV channels consumed via IPTV
- **NVIDIA GPU** -- required on the target node for hardware transcoding
