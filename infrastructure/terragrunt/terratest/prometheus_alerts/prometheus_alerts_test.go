// -------------------------------------------------------------------------------
// Prometheus Alerts Terratest - Round-Trip and Interconnectivity
//
// Author: Alex Freidah
//
// Exercises the prometheus-alerts module against the LIVE consul cluster
// AND the live prometheus instance, complementing the plan-only checks in
// modules/prometheus-alerts/tests/default.tftest.hcl. Each run applies a
// sandbox set of alert groups under prometheus/alerts/zz-terratest-<rand>/,
// reads the values back via consul, then polls /api/v1/rules on prometheus
// to confirm consul-template re-rendered alert_rules.yml and prom reloaded.
// -------------------------------------------------------------------------------

package prometheus_alerts_test

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	teststructure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/hashicorp/consul/api"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// -------------------------------------------------------------------------
// CONSTANTS
// -------------------------------------------------------------------------

// moduleRelativeDir is the path from this _test.go file to the
// prometheus-alerts module directory. Terratest copies it to a temp dir on
// each run so the developer's local .terraform/ is not clobbered.
const moduleRelativeDir = "../../modules/prometheus-alerts"

// defaultPrometheusURL matches the in-cluster service registration; override
// with MUNCHBOX_PROMETHEUS_URL when running outside cluster DNS.
const defaultPrometheusURL = "http://prometheus.service.consul:9090"

// promReloadMaxWait bounds how long we wait for consul-template + SIGHUP to
// re-render alert_rules.yml and prom to pick up the new group. The template
// quiescence is ~5s, plus prom config reload, plus slack.
const promReloadMaxWait = 60 * time.Second

// promReloadPollInterval is how often we poll /api/v1/rules between checks.
const promReloadPollInterval = 3 * time.Second

// -------------------------------------------------------------------------
// TESTS
// -------------------------------------------------------------------------

// TestPrometheusAlerts_RoundTrip applies two sandbox alert groups, asserts
// the KV values round-trip byte-equal via the consul HTTP API, then polls
// prom /api/v1/rules until both group names appear (or times out). This is
// the full apply -> consul KV -> consul-template -> on-disk file -> SIGHUP
// -> prom in-memory rules path; plan-only tests cannot reach past consul KV.
func TestPrometheusAlerts_RoundTrip(t *testing.T) {
	t.Parallel()

	if os.Getenv("CONSUL_HTTP_ADDR") == "" || os.Getenv("CONSUL_HTTP_TOKEN") == "" {
		t.Skip("CONSUL_HTTP_ADDR and CONSUL_HTTP_TOKEN must be set (source munchbox-env.sh)")
	}

	promURL := os.Getenv("MUNCHBOX_PROMETHEUS_URL")
	if promURL == "" {
		promURL = defaultPrometheusURL
	}

	// isolate this run's terraform state from any developer-local
	// .terraform/ in the source tree
	moduleDir := teststructure.CopyTerraformFolderToTemp(t, moduleRelativeDir, ".")

	// sandbox prefix; unique per run, sorts last under the catalog so
	// accidental orphans are easy to spot
	suffix := random.UniqueId()
	prefix := fmt.Sprintf("prometheus/alerts/zz-terratest-%s", suffix)
	key1 := prefix + "-group-a"
	key2 := prefix + "-group-b"
	groupName1 := fmt.Sprintf("terratest-%s-a", suffix)
	groupName2 := fmt.Sprintf("terratest-%s-b", suffix)

	// each KV value is a list entry under `groups:` (the consul-template
	// wraps with `groups:` once); a value of `groups:\n - name: ...` would
	// render double-`groups:` and break the file
	val1 := fmt.Sprintf("- name: %s\n  rules: []\n", groupName1)
	val2 := fmt.Sprintf("- name: %s\n  rules: []\n", groupName2)

	// complex map values don't survive terraform's -var inline parser; pass
	// via TF_VAR_<name> env var which is auto-parsed as JSON
	groupsJSON, err := json.Marshal(map[string]string{
		key1: val1,
		key2: val2,
	})
	require.NoError(t, err, "marshal groups map")

	tfOpts := &terraform.Options{
		TerraformDir: moduleDir,
		EnvVars: map[string]string{
			"TF_VAR_groups": string(groupsJSON),
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, tfOpts)
	terraform.InitAndApply(t, tfOpts)

	// consul client picks up CONSUL_HTTP_ADDR / CONSUL_HTTP_TOKEN from env
	client, err := api.NewClient(api.DefaultConfig())
	require.NoError(t, err, "construct consul client")

	// surface 1: KV round-trip - confirms the consul_keys resource wrote
	// what we passed in
	assertKVRoundTrip(t, client, key1, val1)
	assertKVRoundTrip(t, client, key2, val2)

	// surface 2: prom rules visibility - confirms the full template ->
	// file -> SIGHUP -> in-memory rules chain actually completed
	assertGroupVisibleInProm(t, promURL, groupName1)
	assertGroupVisibleInProm(t, promURL, groupName2)
}

// -------------------------------------------------------------------------
// HELPERS
// -------------------------------------------------------------------------

// assertKVRoundTrip reads `key` from consul and asserts its value equals
// `want`. Hard-stops the test on any error or missing key.
func assertKVRoundTrip(t *testing.T, client *api.Client, key, want string) {
	t.Helper()

	pair, _, err := client.KV().Get(key, nil)
	require.NoError(t, err, "consul KV get %s", key)
	require.NotNilf(t, pair, "key %s should exist after apply", key)
	assert.Equalf(t, want, string(pair.Value), "value at %s round-trips", key)
}

// assertGroupVisibleInProm polls /api/v1/rules until the given group name
// shows up, or fails after promReloadMaxWait. Catches every break in the
// consul-template -> alert_rules.yml -> SIGHUP -> prom chain.
func assertGroupVisibleInProm(t *testing.T, promURL, groupName string) {
	t.Helper()

	maxRetries := int(promReloadMaxWait / promReloadPollInterval)
	_, err := retry.DoWithRetryE(
		t,
		fmt.Sprintf("poll prom /api/v1/rules for group %q", groupName),
		maxRetries,
		promReloadPollInterval,
		func() (string, error) {
			names, fetchErr := fetchPromGroupNames(promURL)
			if fetchErr != nil {
				return "", fetchErr
			}
			if slices.Contains(names, groupName) {
				return "found", nil
			}
			return "", fmt.Errorf("group %q not yet in prom rules (saw %d groups)", groupName, len(names))
		},
	)
	require.NoErrorf(t, err, "prom never reloaded with group %q", groupName)
}

// fetchPromGroupNames returns every group name currently loaded in prom.
// Returns a transport / decode error on any HTTP failure so retry.DoWith
// RetryE can re-try.
func fetchPromGroupNames(promURL string) ([]string, error) {
	resp, err := http.Get(strings.TrimRight(promURL, "/") + "/api/v1/rules")
	if err != nil {
		return nil, fmt.Errorf("GET /api/v1/rules: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("GET /api/v1/rules status=%d", resp.StatusCode)
	}

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read body: %w", err)
	}

	var envelope struct {
		Data struct {
			Groups []struct {
				Name string `json:"name"`
			} `json:"groups"`
		} `json:"data"`
	}
	if err := json.Unmarshal(raw, &envelope); err != nil {
		return nil, fmt.Errorf("decode /api/v1/rules: %w", err)
	}

	out := make([]string, 0, len(envelope.Data.Groups))
	for _, g := range envelope.Data.Groups {
		out = append(out, g.Name)
	}
	return out, nil
}
