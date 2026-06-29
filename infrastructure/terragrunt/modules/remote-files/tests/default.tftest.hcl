# -----------------------------------------------------------------------------
# remote-files module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the (target x bundle x file) fan-out shape: file delivery key
# cardinality, restart key cardinality, bundle sha stability, optional
# check_command compaction, and empty-bundles noop.
# -----------------------------------------------------------------------------

mock_provider "null" {}

variables {
  targets = [
    { name = "alpha", host = "10.0.0.1" },
    { name = "beta", host = "10.0.0.2" },
  ]
  bundles = {
    web = {
      files = {
        index = { content = "<h1>hi</h1>", destination = "/var/www/index.html", mode = "0644" }
        robot = { content = "User-agent: *", destination = "/var/www/robots.txt", mode = "0644" }
      }
      check_command   = "nginx -t"
      restart_command = "systemctl reload nginx"
    }
    cron = {
      files = {
        job = { content = "0 * * * * root /usr/local/bin/x", destination = "/etc/cron.d/x", mode = "0644" }
      }
      restart_command = "systemctl restart cron"
    }
  }
}

# -------------------------------------------------------------------------
# file fan-out: |targets| x sum(|bundle.files|)
# -------------------------------------------------------------------------

run "file_fanout_cardinality" {
  command = plan

  # --- 2 targets * (2 web + 1 cron) = 6 file resources ---
  assert {
    condition     = length(null_resource.file) == 6
    error_message = "file fan-out must be |targets| * sum(|bundle.files|)"
  }

  # --- file keys are target/bundle/file ---
  assert {
    condition     = contains(keys(null_resource.file), "alpha/web/index")
    error_message = "file resource keys must follow target/bundle/file shape"
  }

  # --- file_instances output lists every resolved file key ---
  assert {
    condition     = length(output.file_instances) == 6
    error_message = "file_instances output must list all 6 resolved file keys"
  }

  # --- file_instances output contains the alpha/web/index key ---
  assert {
    condition     = contains(output.file_instances, "alpha/web/index")
    error_message = "file_instances output must contain target/bundle/file keys"
  }

  # --- bundle_shas output keys on every bundle and is non-empty ---
  assert {
    condition     = toset(keys(output.bundle_shas)) == toset(["web", "cron"]) && length(output.bundle_shas["web"]) > 0
    error_message = "bundle_shas output must carry a non-empty sha per bundle"
  }
}

# -------------------------------------------------------------------------
# restart fan-out: |targets| x |bundles|
# -------------------------------------------------------------------------

run "restart_fanout_cardinality" {
  command = plan

  # --- 2 targets * 2 bundles = 4 restart resources ---
  assert {
    condition     = length(null_resource.restart) == 4
    error_message = "restart fan-out must be |targets| * |bundles|"
  }

  # --- restart keys are target/bundle ---
  assert {
    condition     = contains(keys(null_resource.restart), "beta/cron")
    error_message = "restart keys must follow target/bundle shape"
  }

  # --- restart_instances output lists every resolved target/bundle pair ---
  assert {
    condition     = length(output.restart_instances) == 4
    error_message = "restart_instances output must list all 4 target/bundle pairs"
  }

  # --- restart_instances output contains the beta/cron pair ---
  assert {
    condition     = contains(output.restart_instances, "beta/cron")
    error_message = "restart_instances output must contain target/bundle keys"
  }
}

# -------------------------------------------------------------------------
# bundle_sha trigger matches between file and restart instances of same bundle
# -------------------------------------------------------------------------

run "bundle_sha_consistency" {
  command = plan

  # --- alpha/web file shares the same sha as alpha/web restart ---
  assert {
    condition = (
      null_resource.file["alpha/web/index"].triggers.bundle_sha ==
      null_resource.restart["alpha/web"].triggers.bundle_sha
    )
    error_message = "bundle_sha must propagate identically into file + restart triggers"
  }

  # --- different bundles produce different shas ---
  assert {
    condition = (
      null_resource.restart["alpha/web"].triggers.bundle_sha !=
      null_resource.restart["alpha/cron"].triggers.bundle_sha
    )
    error_message = "distinct bundles must hash to distinct bundle_shas"
  }
}

# -------------------------------------------------------------------------
# empty bundles input -> zero file + zero restart resources
# -------------------------------------------------------------------------

run "empty_bundles" {
  command = plan

  variables {
    bundles = {}
  }

  # --- no bundles -> no file resources ---
  assert {
    condition     = length(null_resource.file) == 0
    error_message = "empty bundles must produce zero file resources"
  }

  # --- no bundles -> no restart resources ---
  assert {
    condition     = length(null_resource.restart) == 0
    error_message = "empty bundles must produce zero restart resources"
  }
}
