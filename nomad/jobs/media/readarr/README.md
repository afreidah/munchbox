# Readarr

Automates ebook and audiobook acquisition by monitoring RSS feeds and
coordinating with indexers managed by Prowlarr. Organizes downloaded content
into the book library on gdrive-secondary NFS, which Kavita serves as a
reading interface.

## Dependencies

- **Deluge** -- download client for fetching books (VPN-tunneled)
- **Prowlarr** -- provides indexer configurations via sync
- **Kavita** -- serves the organized book library for reading
