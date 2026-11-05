# -------------------------------------------------------------------------------
# static-analysis - Make targets against one commit of a Go repository
#
# Project: Munchbox / Author: Alex Freidah
#
# Runs on Cloud Run, so the repository must be public on GitHub: Cloud Run cannot
# reach Forgejo, and Vagabond has no way to hand a job a token.
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
    providers    = ["gcp-cloud-run"]
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

    # --- Whole vCPUs: Cloud Run bills rounded up, and charges follow this block ---
    resources {
      cpu    = 2000
      memory = 4096
    }

    timeout = "20m"
  }
}
