# firecracker

Readies a node to run Vagabond workloads in Firecracker microVMs, for an agent started with `-firecracker`:

- The `firecracker` system user and group at UID and GID 990, the agent's `-firecracker-uid` and `-firecracker-gid`. A converge fails if either is already taken.
- A device-mapper thin pool, `containerd-thinpool`, over two sparse files in `/var/lib/containerd-thinpool`, brought up at boot by `containerd-thinpool.service` ahead of containerd.
- `/etc/containerd/config.toml` with containerd's devmapper snapshotter on that pool, which turns each image into the block device a microVM boots from. CRI's server stays disabled, as in Docker's stock file. A change restarts containerd; Docker's containers keep running.

Only `nomad-client-04` runs this today. The node also needs `/dev/kvm`, and Docker's containerd 2.x.

## Recipes

| Recipe | Purpose |
|---|---|
| `default` | Empty; opt in via run_list. |
| `host` | The user, the thin pool and its unit, containerd's config. |

## Attributes

Under `firecracker.host`:

| Attribute | Default | Notes |
|---|---|---|
| `pool_dir` | `/var/lib/containerd-thinpool` | Holds the `data` and `meta` files. |
| `pool_name` | `containerd-thinpool` | The device-mapper name containerd's config names. |
| `data_size` | `50G` | Fixed when the file is first made. Sparse, but must fit the disk once microVMs fill it. |
| `meta_size` | `1G` | Fixed when the file is first made. |
| `base_image_size` | `10GB` | Each image's snapshot: the microVM's disk. |
| `fs_type` | `ext4` | The filesystem on each snapshot; the guest kernel needs it built in. |
| `uid`, `gid` | `990` | |

## Failure modes

- **The pool fails to come up:** `containerd-thinpool.service` fails, containerd and Docker start without it, and `ctr plugins ls` shows `devmapper` as `skip` or `error`. The agent's `-firecracker` then fails at startup with `containerd's devmapper snapshotter did not load`. `journalctl -u containerd-thinpool` has the reason.
- **The pool or the disk under it fills:** writes inside the microVMs stall, and fail after dm-thin's `no_space_timeout`, 60 seconds by default. Grow the disk or stop workloads; `dmsetup status containerd-thinpool` shows the pool's use.

## Testing

```
make verify
make kitchen
```

The kitchen suite converges a debian-12 VM with Docker's containerd, then checks the user, the pool, and that containerd loads devmapper on it. Booting microVMs needs `/dev/kvm` and the agent, so that is verified on the node.
