# Allow read access to the Nomad token secret for Hashi-UI
path "secret/data/hashiuisecret" {
  capabilities = ["read"]
}
