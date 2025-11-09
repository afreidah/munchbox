################################################################################
# Project: Munchbox
# Author: Alex Freidah
#
# Munchbox Universal Job Template - Main Entry Point
#
# This template automatically merges munchbox-defaults.hcl with job-specific
# variable files. Jobs only need to define what's unique to them. Supports
# resource tiers, deployment profiles, meta templates, and constraint presets.
#
# This file imports partial templates for better organization:
# - templates/job-header.tpl: Job-level configuration and metadata
# - templates/group-config.tpl: Task group configuration
# - templates/single-task.tpl: Single task mode
# - templates/multi-task.tpl: Multi-task mode
#
# Usage:
#   levant deploy \
#     -var-file=munchbox-defaults.hcl \
#     -var-file=nomad-jobs/myapp.hcl \
#     munchbox-job.nomad.tpl
################################################################################

# -----------------------------------------------------------------------------
# Load Defaults and Profiles
# -----------------------------------------------------------------------------

[[- $defaults := .defaults ]]
[[- $resource_tiers := .resource_tiers ]]
[[- $traefik_defaults := .traefik_defaults ]]
[[- $vault_defaults := .vault_defaults ]]
[[- $identity_defaults := .identity_defaults ]]

# --- Determine resource tier ---
[[- $tier := .resource_tier | default "medium" ]]
[[- $resources := index $resource_tiers $tier ]]

# --- Load deployment profile ---
[[- $deployment_profile := .deployment_profile | default "standard" ]]
[[- $update := index .deployment_profiles $deployment_profile ]]

# --- Load meta profile ---
[[- $meta_profile := .meta_profile | default "tier3" ]]
[[- $meta_defaults := index .meta_profiles $meta_profile ]]

# --- Load category defaults ---
[[- $category := .category | default "web" ]]
[[- $category_defaults := index .category_defaults $category ]]

# --- Load constraint preset ---
[[- $constraint_preset := .constraint_preset | default "" ]]

# --- Load reschedule preset ---
[[- $reschedule_preset := .reschedule_preset | default "standard" ]]
[[- $reschedule := index .reschedule_presets $reschedule_preset ]]

# --- Load network preset ---
[[- $network_preset := .network_preset | default "bridge" ]]
[[- $network_defaults := index .network_presets $network_preset ]]

# -----------------------------------------------------------------------------
# Job Definition
# -----------------------------------------------------------------------------

[[ template "templates/job-header.tpl" . ]]

  # ---------------------------------------------------------------------------
  # Task Group
  # ---------------------------------------------------------------------------

  [[ template "templates/group-config.tpl" . ]]

    # -------------------------------------------------------------------------
    # Tasks
    # -------------------------------------------------------------------------

    [[- if .task ]]
    [[ template "templates/single-task.tpl" . ]]
    [[- end ]]

    [[- if .tasks ]]
    [[ template "templates/multi-task.tpl" . ]]
    [[- end ]]
  }
}
