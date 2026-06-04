# -----------------------------------------------------------------------------
# TEMPORAL-CONFIG MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Manages Temporal Schedules on the self-hosted frontend. Each schedule starts a
# workflow on its task queue with a JSON input that deserializes into the
# workflow's config struct. Schedule definitions come from the env_helper.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# WORKFLOW SCHEDULES
# -----------------------------------------------------------------------------

resource "temporal_schedule" "this" {
  for_each = var.schedules

  namespace   = each.value.namespace
  schedule_id = each.value.schedule_id

  spec = {
    calendar_items = [{
      year         = each.value.year
      minute       = each.value.minute
      hour         = each.value.hour
      day_of_month = each.value.day_of_month
      month        = each.value.month
      day_of_week  = each.value.day_of_week
      second       = each.value.second
    }]
    time_zone = each.value.time_zone
    jitter    = each.value.jitter
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

  # The provider plans calendar year="*", but the API stores "match all years"
  # as an empty range and returns null, so spec never converges on re-plan.
  # Ignore server-side spec drift; change a schedule's timing with
  # `apply -replace` on the affected instance.
  lifecycle {
    ignore_changes = [spec]
  }
}
