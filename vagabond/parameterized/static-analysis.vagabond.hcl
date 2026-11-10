# -------------------------------------------------------------------------------
# static-analysis - Make targets against one commit of a Go repository
#
# Project: Munchbox / Author: Alex Freidah
#
# Runs on Cloud Run or Code Engine, and on the homelab pool once their free
# quota runs out. The repository must be public on GitHub, since neither cloud
# can reach Forgejo.
#
#   vagabond job register vagabond/parameterized/static-analysis.vagabond.hcl
#   vagabond job dispatch -meta repo=afreidah/vagabond -meta commit=<sha> \
#     -meta targets="vet lint fmt-check govulncheck" static-analysis
# -------------------------------------------------------------------------------

job "static-analysis" {
  parameterized {
    meta_required = ["repo", "commit", "targets"]
  }

  routing {
    providers    = ["gcp-cloud-run", "ibm-code-engine", "homelab"]
    max_cost_usd = 0
  }

  task "make" {
    driver = "container"

    # --- Shallow-fetches the commit, since clone cannot name an arbitrary SHA ---
    config {
      image   = "golang:1.27"
      command = "sh"
      args = ["-ec", <<-EOT
        git init -q /src
        cd /src
        git remote add origin "https://github.com/$VAGABOND_META_REPO.git"
        git fetch -q --depth 1 origin "$VAGABOND_META_COMMIT"
        git checkout -q FETCH_HEAD
        make $VAGABOND_META_TARGETS
      EOT
      ]
    }

    # --- Charges follow this block, so it is sized to what both clouds bill:
    #     whole vCPUs for Cloud Run, and 3814 MiB is Code Engine's 4G at 2 vCPU.
    #     4096 would run there at 8G while the ledger counted 4 GiB. ---
    resources {
      cpu    = 2000
      memory = 3814
    }

    timeout = "20m"
  }
}
