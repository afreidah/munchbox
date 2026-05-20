# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Resource:: munchbox_base_apt_lock_wait
#
# Blocks the chef run until apt's frontend lock + lists lock are both
# free. Drop this at the top of any install action that touches apt so
# unattended-upgrades / apt-daily timers (especially noisy on cloud
# images) don't race the cookbook and fail the run.
#
# Properties:
#   timeout - Hard cap in seconds; resource fails if locks aren't free by then.
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_base_apt_lock_wait

property :timeout, Integer, default: 600

default_action :wait

# --- Poll fuser on both lock files; sleep + retry until free or timeout ---
action :wait do
  execute "munchbox_base apt lock wait (timeout #{new_resource.timeout}s)" do
    command <<~CMD
      end=$(( $(date +%s) + #{new_resource.timeout} ))
      while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock >/dev/null 2>&1; do
        [ $(date +%s) -gt $end ] && { echo "apt lock still held after #{new_resource.timeout}s" >&2; exit 1; }
        sleep 5
      done
    CMD
    timeout new_resource.timeout + 30
  end
end
