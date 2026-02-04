# Docker Registry

Private container image registry for the cluster. Stores custom-built images
(patroni, theme-server, dashboard, etc.) used by Nomad jobs. Registry data
persists on the Google Drive NFS mount for durability. The companion UI
provides read-only browser access to repository contents.

Two separate jobs: `registry` runs the registry server, `registry-ui` runs
the web interface.
