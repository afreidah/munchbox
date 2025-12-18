# Munchbox Infrastructure Analysis - December 2024

## Production-Grade Gaps

### High Priority

1. **No backup strategy for databases** - You have Postgres primary/replica but no offsite backups. The temporal-backup-trigger exists but I don't see actual pg_dump jobs or S3/B2 uploads. If your Proxmox storage dies, you lose Nextcloud data, Temporal workflows, Woodpecker history, and Authentik configs.

2. **Single point of failure: Traefik on stabler** - If stabler goes down, all ingress stops. Consider running Traefik on multiple nodes with Consul-based failover or at least a standby.

3. **No secrets rotation** - Vault is there but credentials appear static. Database passwords, API keys should rotate periodically.

4. **Missing uptime monitoring** - You have Blackbox Exporter but I don't see external uptime checks. If your whole network goes down, who tells you? Consider UptimeRobot, Healthchecks.io, or Better Stack (all have free tiers).

5. **No disaster recovery runbook** - How do you rebuild from scratch? Document the bootstrap order.

### Medium Priority

6. **Redis has no persistence guarantees** - Using allkeys-lru with RDB snapshots to gdrive-secondary. If Redis crashes mid-write, you lose session data. Consider AOF for Authentik sessions.

7. **Consul/Nomad not HA** - Looks like single server. For true prod, you'd want 3 servers (you have the Oracle nodes for this).

8. **No rate limiting on internal services** - Nextcloud has it, but Prometheus/Grafana/Consul UI don't. A rogue script could DoS your monitoring.

9. **Log retention too short** - 5 days in Loki isn't enough for incident investigation. Consider 30 days minimum.

---

## Services for Friends & Family

### Easy Wins (Low Resource)

| Service | What It Does | Why They'd Want It |
|---------|--------------|-------------------|
| **Immich** | Google Photos replacement | Self-hosted photo backup with ML face recognition |
| **Paperless-ngx** | Document management | Scan receipts/docs, OCR search, organized archive |
| **Mealie** | Recipe manager | Meal planning, grocery lists, recipe import from URLs |
| **Homebox** | Home inventory | Track belongings, warranties, manuals |
| **Linkding** | Bookmark manager | Save/organize links with tags |
| **Actual Budget** | YNAB alternative | Privacy-focused budgeting |

### Medium Effort

| Service | What It Does | Notes |
|---------|--------------|-------|
| **Audiobookshelf** | Audiobook/podcast server | Like Jellyfin but for audiobooks |
| **Kavita** | eBook/comic reader | Calibre alternative with better UI |
| **Tandoor** | Advanced recipe manager | More features than Mealie |
| **Vikunja** | Task/project management | Todoist/Trello replacement |
| **Memos** | Note-taking | Lightweight, privacy-focused |

### For Gamers in Your Circle

| Service | What It Does |
|---------|--------------|
| **Crafty Controller** | Minecraft server manager |
| **Pterodactyl** | Game server panel (Valheim, etc) |
| **Lancache** | Steam/Epic game download cache |

---

## Cool Shit You Could Run

### AI/ML (You have ARM + x86)

- **Ollama** - Run local LLMs (Llama, Mistral). Your nomad-client-01 with 4 CPU could handle 7B models
- **LocalAI** - OpenAI-compatible API for local models
- **Whisper** - Speech-to-text for transcribing media
- **Stable Diffusion** - Image generation (if you have any GPU)

### Automation

- **n8n** or **Activepieces** - Zapier alternatives, self-hosted workflow automation
- **Huginn** - Build agents that monitor and act on your behalf
- **Changedetection.io** - Monitor websites for changes (price drops, etc)

### Development

- **Gitea/Forgejo** - Self-hosted GitHub (lighter than GitLab)
- **Code-server** - VS Code in browser
- **Devcontainers** - Remote dev environments

### Network/Security

- **Crowdsec** - Collaborative IPS, shares threat intel
- **Netbird/Tailscale** - Better than raw WireGuard for user devices
- **Wazuh** - SIEM/XDR (might be overkill but it's cool)

### Analytics

- **Plausible/Umami** - Privacy-focused web analytics for your public sites
- **Uptime Kuma** - Beautiful status page + monitoring

---

## Free Tier Cloud Resources You're Missing

### Compute

| Provider | Free Tier | Good For |
|----------|-----------|----------|
| **Oracle Cloud** | 4 ARM OCPU + 24GB RAM (you're using 2GB of 24GB!) | More workloads, HA Consul/Nomad |
| **Google Cloud** | e2-micro (2 vCPU shared, 1GB) | External monitoring, uptime checks |
| **AWS** | t2.micro (750 hrs/mo for 12 mo) | Edge services, Lambda functions |
| **Azure** | B1S (750 hrs/mo for 12 mo) | Redundant Cloudflare tunnel endpoint |
| **Fly.io** | 3 shared-cpu VMs, 256MB each | Lightweight edge services |
| **Railway** | $5/mo credit | Quick deploys, databases |
| **Render** | Static sites, cron jobs | Public sites hosting |

### Storage

| Provider | Free Tier | Good For |
|----------|-----------|----------|
| **Cloudflare R2** | 10GB + 1M requests/mo | Backup destination, no egress fees |
| **Backblaze B2** | 10GB | Encrypted database backups |
| **Wasabi** | No free tier but $7/TB/mo | Cheap bulk storage |

### Databases

| Provider | Free Tier |
|----------|-----------|
| **Neon** | 0.5GB Postgres, autoscaling |
| **PlanetScale** | 5GB MySQL |
| **Supabase** | 500MB Postgres + auth |
| **Upstash** | 10K commands/day Redis |

### Monitoring/Logging

| Provider | Free Tier |
|----------|-----------|
| **Grafana Cloud** | 10K metrics, 50GB logs, 50GB traces |
| **Better Stack** | 1 monitor, 3 team members |
| **Healthchecks.io** | 20 checks |
| **Sentry** | 5K errors/mo |

### DNS/CDN

| Provider | Free Tier |
|----------|-----------|
| **Cloudflare** | You're already using this |
| **BunnyCDN** | 14-day trial, then cheap |

---

## Top Recommendations

1. **Add Immich** - Everyone wants photo backup, it's the killer app for family clouds
2. **External uptime monitoring** - Healthchecks.io or Better Stack free tier
3. **Cloudflare R2 for backups** - Set up pg_dump → R2 nightly
4. **Finish claiming Oracle ARM** - You have 22GB RAM unused in free tier
5. **Add Uptime Kuma** - Give friends a status page they can check
6. **Consider Ollama** - Local AI is genuinely useful for coding, writing, etc.
