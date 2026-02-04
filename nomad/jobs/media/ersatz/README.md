# ErsatzTV

Creates virtual linear TV channels from the existing media library,
simulating a traditional broadcast experience with scheduling and filler
content. Shares the GPU node with Jellyfin for real-time NVENC transcoding
of channel streams.

## Dependencies

- **Jellyfin** -- co-located on the same node; consumes ErsatzTV channels
- **NVIDIA GPU** -- required for real-time stream transcoding
