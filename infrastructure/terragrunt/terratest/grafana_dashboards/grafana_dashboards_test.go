// -------------------------------------------------------------------------------
// Grafana Dashboards Terratest - Round-Trip and Folder Visibility
//
// Author: Alex Freidah
//
// Exercises the grafana-dashboards module end-to-end against the LIVE
// Grafana instance. Writes a single minimal dashboard JSON to a temp dir,
// applies the module, then verifies (1) the dashboard round-trips via
// /api/dashboards/uid/<uid> with matching uid + title, and (2) it appears
// in the configured folder via /api/search?folderUIDs=<uid>. Catches the
// apply-time gotchas plan-only can't, e.g. the dashboard_provisioning lock
// that bit us on the original rollout (#127).
// -------------------------------------------------------------------------------

package grafana_dashboards_test

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"slices"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	teststructure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// -------------------------------------------------------------------------
// CONSTANTS
// -------------------------------------------------------------------------

// moduleRelativeDir is the path from this _test.go file to the
// grafana-dashboards module directory.
const moduleRelativeDir = "../../modules/grafana-dashboards"

// defaultGrafanaURL matches the env_helper for the live deploy. Override
// via MUNCHBOX_GRAFANA_URL when running from a host that can't resolve
// .service.consul.
const defaultGrafanaURL = "http://grafana.service.consul:3030"

// defaultFolderUID matches the module's var.folder_uid default. Folder is
// assumed to exist; the test asserts the dashboard ends up in it.
const defaultFolderUID = "munchbox-folder"

// folderVisibleMaxWait bounds the wait between apply finishing and the
// dashboard showing up in folder-scoped search. Provider apply is usually
// synchronous, but the search index lags by a couple seconds.
const folderVisibleMaxWait = 20 * time.Second

// folderVisiblePollInterval is how often we poll /api/search between checks.
const folderVisiblePollInterval = 2 * time.Second

// -------------------------------------------------------------------------
// TESTS
// -------------------------------------------------------------------------

// TestGrafanaDashboards_RoundTrip applies a sandbox dashboard, asserts the
// uid + title round-trip via /api/dashboards/uid/<uid>, then asserts the
// dashboard appears in the configured folder via /api/search. Together
// these confirm the full file -> provider -> Grafana DB -> search index
// path, which plan-only cannot reach.
func TestGrafanaDashboards_RoundTrip(t *testing.T) {
	t.Parallel()

	user := os.Getenv("TF_VAR_grafana_admin_user")
	pass := os.Getenv("TF_VAR_grafana_admin_password")
	if user == "" || pass == "" {
		t.Skip("TF_VAR_grafana_admin_user + TF_VAR_grafana_admin_password must be set (source munchbox-env.sh)")
	}

	grafanaURL := os.Getenv("MUNCHBOX_GRAFANA_URL")
	if grafanaURL == "" {
		grafanaURL = defaultGrafanaURL
	}

	// one minimal dashboard JSON in a unique temp dir; uid + title both
	// name-spaced so a leaked dashboard is easy to spot in the UI
	suffix := random.UniqueId()
	uid := fmt.Sprintf("zz-terratest-%s", suffix)
	title := fmt.Sprintf("zz-terratest-%s", suffix)

	dashboardsDir := t.TempDir()
	dashboardJSON := map[string]any{
		"uid":           uid,
		"title":         title,
		"schemaVersion": 39,
		"version":       1,
		"panels":        []any{},
		"tags":          []string{"terratest"},
	}
	body, err := json.MarshalIndent(dashboardJSON, "", "  ")
	require.NoError(t, err, "marshal sandbox dashboard")
	require.NoError(t, os.WriteFile(filepath.Join(dashboardsDir, uid+".json"), body, 0o644))

	// isolate this run's terraform state from the developer-local one
	moduleDir := teststructure.CopyTerraformFolderToTemp(t, moduleRelativeDir, ".")

	tfOpts := &terraform.Options{
		TerraformDir: moduleDir,
		EnvVars: map[string]string{
			"TF_VAR_grafana_url":            grafanaURL,
			"TF_VAR_grafana_admin_user":     user,
			"TF_VAR_grafana_admin_password": pass,
			"TF_VAR_dashboards_dir":         dashboardsDir,
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, tfOpts)
	terraform.InitAndApply(t, tfOpts)

	// surface 1: direct dashboard fetch - 200 + matching title/uid means
	// the provider didn't munge the body on apply
	dash := getDashboard(t, grafanaURL, user, pass, uid)
	require.NotNilf(t, dash, "dashboard %s should exist after apply", uid)
	assert.Equal(t, uid, dash["uid"], "uid round-trips")
	assert.Equal(t, title, dash["title"], "title round-trips")

	// surface 2: folder visibility - confirms the folder_uid input
	// actually landed the dashboard in the right folder, not just the
	// general dashboard pool
	assertDashboardInFolder(t, grafanaURL, user, pass, uid, defaultFolderUID)
}

// -------------------------------------------------------------------------
// HELPERS
// -------------------------------------------------------------------------

// getDashboard fetches /api/dashboards/uid/<uid> with basic auth and
// returns the .dashboard sub-object, or nil if the API said 404.
func getDashboard(t *testing.T, grafanaURL, user, pass, uid string) map[string]any {
	t.Helper()

	req, err := http.NewRequest("GET", grafanaURL+"/api/dashboards/uid/"+uid, nil)
	require.NoError(t, err, "build grafana GET")
	req.Header.Set("Authorization", basicAuthHeader(user, pass))

	resp, err := http.DefaultClient.Do(req)
	require.NoErrorf(t, err, "GET %s", req.URL)
	defer func() { _ = resp.Body.Close() }()

	if resp.StatusCode == http.StatusNotFound {
		return nil
	}
	require.Equalf(t, http.StatusOK, resp.StatusCode, "GET %s", req.URL)

	raw, err := io.ReadAll(resp.Body)
	require.NoError(t, err, "read body")
	var envelope map[string]any
	require.NoError(t, json.Unmarshal(raw, &envelope), "parse grafana envelope")

	dash, _ := envelope["dashboard"].(map[string]any)
	return dash
}

// assertDashboardInFolder polls /api/search?folderUIDs=<folder> until the
// dashboard uid appears in the folder's listing, or fails after
// folderVisibleMaxWait. Confirms the folder_uid input actually applied.
func assertDashboardInFolder(t *testing.T, grafanaURL, user, pass, dashboardUID, folderUID string) {
	t.Helper()

	maxRetries := int(folderVisibleMaxWait / folderVisiblePollInterval)
	_, err := retry.DoWithRetryE(
		t,
		fmt.Sprintf("poll grafana /api/search for dashboard %q in folder %q", dashboardUID, folderUID),
		maxRetries,
		folderVisiblePollInterval,
		func() (string, error) {
			uids, fetchErr := searchFolderDashboardUIDs(grafanaURL, user, pass, folderUID)
			if fetchErr != nil {
				return "", fetchErr
			}
			if slices.Contains(uids, dashboardUID) {
				return "found", nil
			}
			return "", fmt.Errorf("dashboard %q not yet in folder %q (saw %d entries)", dashboardUID, folderUID, len(uids))
		},
	)
	require.NoErrorf(t, err, "dashboard %q never appeared in folder %q", dashboardUID, folderUID)
}

// searchFolderDashboardUIDs returns every dashboard uid in the given
// folder. Returns a transport / decode error on any HTTP failure so
// retry.DoWithRetryE can re-try.
func searchFolderDashboardUIDs(grafanaURL, user, pass, folderUID string) ([]string, error) {
	q := url.Values{}
	q.Set("folderUIDs", folderUID)
	q.Set("type", "dash-db")

	req, err := http.NewRequest("GET", grafanaURL+"/api/search?"+q.Encode(), nil)
	if err != nil {
		return nil, fmt.Errorf("build grafana search GET: %w", err)
	}
	req.Header.Set("Authorization", basicAuthHeader(user, pass))

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("GET %s: %w", req.URL, err)
	}
	defer func() { _ = resp.Body.Close() }()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("GET %s status=%d", req.URL, resp.StatusCode)
	}

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read body: %w", err)
	}

	var hits []struct {
		UID string `json:"uid"`
	}
	if err := json.Unmarshal(raw, &hits); err != nil {
		return nil, fmt.Errorf("decode /api/search: %w", err)
	}

	out := make([]string, 0, len(hits))
	for _, h := range hits {
		out = append(out, h.UID)
	}
	return out, nil
}

// basicAuthHeader builds the Authorization header value for HTTP basic
// auth without pulling in net/http/httputil for a one-liner.
func basicAuthHeader(user, pass string) string {
	return "Basic " + base64.StdEncoding.EncodeToString([]byte(user+":"+pass))
}
