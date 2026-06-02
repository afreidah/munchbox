# -----------------------------------------------------------------------------
# CLOUDFLARE-API-TOKEN MODULE - PROVIDER CONFIG
# -----------------------------------------------------------------------------
#
# Cloudflare provider reads CLOUDFLARE_API_TOKEN from the env. The bootstrap
# token must carry User:API Tokens:Edit to mint the tokens this module owns.
# No wiring needed; block present so the source resolves.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

provider "cloudflare" {}
