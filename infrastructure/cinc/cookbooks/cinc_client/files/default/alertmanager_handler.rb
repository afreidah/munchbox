# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_client
# Handler:: alertmanager_handler
#
# Chef exception handler that posts a failed converge to Alertmanager, so the
# notification names what broke rather than only that something did. Registered
# from /etc/cinc/client.d by the handler recipe.
#
# No resolve is ever sent. Alertmanager drops an alert once its endsAt passes,
# so a fleet that starts converging again clears itself; the window has to
# outlast the gap between runs or the alert flaps between them.
#
# Every failure inside the handler is swallowed, because a handler that raised
# would replace the converge error an operator needs with its own.
# -------------------------------------------------------------------------------

require 'chef/handler'
require 'json'
require 'net/http'
require 'uri'

module Munchbox
  # Posts CincRunFailed to Alertmanager when a converge fails.
  class AlertmanagerHandler < Chef::Handler
    # --- Values come from the client.d drop-in, so all keys are strings ---
    def initialize(opts = {})
      super()
      @endpoint = opts['endpoint'].to_s
      @window   = opts['window'].to_i
      @severity = opts['severity'].to_s
      @timeout  = opts['timeout'].to_i
    end

    # --- Chef's entry point; only ever called for a run that raised ---
    def report
      return if @endpoint.empty?

      post(payload)
    rescue StandardError => e
      Chef::Log.error("alertmanager handler: #{e.class}: #{e.message}")
    end

    private

    # --- Alertmanager takes a list; timestamps are RFC3339 in UTC ---
    def payload
      now = Time.now.utc
      [{
        'labels' => {
          'alertname' => 'CincRunFailed',
          'node' => failing_node,
          'severity' => @severity,
        },
        'annotations' => {
          'summary' => "cinc-client run failed on #{failing_node}",
          'description' => description,
        },
        'startsAt' => rfc3339(now),
        'endsAt' => rfc3339(now + @window),
      }]
    end

    # --- Alertmanager rejects anything else as a timestamp ---
    def rfc3339(time)
      time.strftime('%Y-%m-%dT%H:%M:%SZ')
    end

    # --- run_status carries no node when the run dies before one is built ---
    def failing_node
      run_status&.node&.name || 'unknown'
    end

    # --- First line only; a stacktrace is unreadable as an annotation ---
    def description
      message = run_status&.exception&.message || 'no exception recorded'
      message.split("\n").first.to_s[0, 500]
    end

    # --- A non-2xx is logged rather than raised; see the file header ---
    def post(body)
      uri = URI.join(@endpoint, '/api/v2/alerts')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = @timeout
      http.read_timeout = @timeout

      request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
      request.body = JSON.generate(body)

      response = http.request(request)
      return if response.code.to_i < 300

      Chef::Log.error("alertmanager handler: #{uri} returned #{response.code}")
    end
  end
end
