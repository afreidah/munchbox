# Project: Munchbox
# Application: deluge-vpn
# Purpose: Torrent client with VPN tunnel

app "deluge-vpn" {
  build {
    use "docker" {
      buildkit   = true
      context    = "./deluge-vpn"
      dockerfile = "./deluge-vpn/Dockerfile"
    }
  }

  deploy {
    use "null" {}
  }

  release {
    use "docker" {
      tag = "${var.registry_host}:${var.registry_port}/deluge-vpn:${var.git_ref}"
    }
  }
}
