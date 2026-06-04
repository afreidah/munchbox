# -----------------------------------------------------------------------------
# TEMPORAL-CONFIG MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Manages Temporal Schedules on the self-hosted frontend. Each schedule fires a
# workflow on a cron against its task queue, replacing the Nomad periodic
# trigger jobs. Schedule definitions (cron, workflow, JSON input) come from the
# env_helper; the input string is the workflow's argument payload.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# WORKFLOW SCHEDULES
# -----------------------------------------------------------------------------

resource "temporal_schedule" "this" {
  for_each = var.schedules

  namespace   = each.value.namespace
  schedule_id = each.value.schedule_id

  spec = {
    cron_items = [each.value.cron]
    time_zone  = each.value.time_zone
    jitter     = each.value.jitter
  }

  action = {
    workflow = {
      workflow_type     = each.value.workflow_type
      task_queue        = each.value.task_queue
      workflow_id       = each.value.workflow_id
      input             = each.value.input
      execution_timeout = each.value.execution_timeout
      run_timeout       = each.value.run_timeout
      task_timeout      = each.value.task_timeout
    }
  }

  policy_config = {
    overlap_policy   = each.value.overlap_policy
    catchup_window   = each.value.catchup_window
    pause_on_failure = each.value.pause_on_failure
  }

  state = {
    paused = each.value.paused
  }
}
