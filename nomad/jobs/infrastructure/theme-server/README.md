# Theme Server

Serves custom Catppuccin Mocha CSS files for services that support external
CSS injection (arr stack, Deluge, Vault, Pi-hole). Provides consistent
visual theming across the cluster without modifying upstream container images.
Runs on an Oracle Cloud node since it serves only static files and has no
local storage requirements.
