# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_client
# Recipe:: handler
#
# Installs the Alertmanager exception handler via cinc_client_handler, so a
# node that fails a converge says so with the exception that caused it. Removes
# the handler when disabled, rather than leaving a drop-in nothing manages.
# -------------------------------------------------------------------------------

cinc_client_handler 'alertmanager' do
  endpoint node[cookbook]['handler']['endpoint']
  window   node[cookbook]['handler']['window']
  severity node[cookbook]['handler']['severity']
  timeout  node[cookbook]['handler']['timeout']
  path     node[cookbook]['handler']['path']
  action(node[cookbook]['handler']['enabled'] ? :install : :remove)
end
