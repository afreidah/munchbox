# Project Zomboid

Dedicated multiplayer Project Zomboid server using the SteamCMD community
image. Manages its own SteamCMD installation, server updates, and world
state through a custom entrypoint script.

## Architecture

The server runs as a single stateful service with host networking for
stable UDP behavior. A persistent host volume stores the entire server
state: SteamCMD binaries, game server files, world saves, Workshop
content, and configuration. The entrypoint script handles first-run
bootstrapping (SteamCMD install, server download) and subsequent updates
on every restart.

## Notable Configuration

- Pinned to a stateful node class to keep world data local and avoid
  rescheduling across nodes
- Conservative reschedule policy (1 attempt per hour) prevents the world
  from bouncing around the cluster
- 2-minute kill timeout allows the autosave system to complete before
  shutdown, preventing world corruption
- JVM tuned with G1GC and 6GB heap for predictable pause times

## Dependencies

- **Steam network** -- SteamCMD downloads and Workshop content
