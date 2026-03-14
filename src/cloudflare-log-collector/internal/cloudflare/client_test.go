// -------------------------------------------------------------------------------
// Cloudflare GraphQL Client Tests
//
// Author: Alex Freidah
//
// Tests for the Cloudflare GraphQL API client using httptest servers to mock
// API responses. Covers successful queries, error handling, and response parsing
// for both firewall events and HTTP traffic datasets.
// -------------------------------------------------------------------------------

package cloudflare

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// -------------------------------------------------------------------------
// FIREWALL EVENTS
// -------------------------------------------------------------------------

func TestQueryFirewallEvents_Success(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		verifyAuthHeader(t, r)
		verifyContentType(t, r)

		resp := graphQLResponse{
			Data: mustMarshal(t, firewallResponse{
				Viewer: struct {
					Zones []struct {
						FirewallEventsAdaptive []FirewallEvent `json:"firewallEventsAdaptive"`
					} `json:"zones"`
				}{
					Zones: []struct {
						FirewallEventsAdaptive []FirewallEvent `json:"firewallEventsAdaptive"`
					}{
						{
							FirewallEventsAdaptive: []FirewallEvent{
								{
									Action:   "block",
									ClientIP: "1.2.3.4",
									Datetime: "2026-03-13T10:00:00Z",
									RayName:  "abc123",
								},
							},
						},
					},
				},
			}),
		}
		writeJSON(t, w, resp)
	}))
	t.Cleanup(ts.Close)

	client := newTestClient(ts.URL, "test-token", "test-zone")

	events, err := client.QueryFirewallEvents(context.Background(),
		time.Now().Add(-1*time.Hour), time.Now())
	if err != nil {
		t.Fatalf("QueryFirewallEvents() error = %v", err)
	}

	if len(events) != 1 {
		t.Fatalf("got %d events, want 1", len(events))
	}
	if events[0].Action != "block" {
		t.Errorf("action = %q, want %q", events[0].Action, "block")
	}
	if events[0].ClientIP != "1.2.3.4" {
		t.Errorf("clientIP = %q, want %q", events[0].ClientIP, "1.2.3.4")
	}
}

func TestQueryFirewallEvents_EmptyZones(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := graphQLResponse{
			Data: mustMarshal(t, firewallResponse{}),
		}
		writeJSON(t, w, resp)
	}))
	t.Cleanup(ts.Close)

	client := newTestClient(ts.URL, "test-token", "test-zone")

	events, err := client.QueryFirewallEvents(context.Background(),
		time.Now().Add(-1*time.Hour), time.Now())
	if err != nil {
		t.Fatalf("QueryFirewallEvents() error = %v", err)
	}

	if events != nil {
		t.Errorf("expected nil events for empty zones, got %d", len(events))
	}
}

// -------------------------------------------------------------------------
// HTTP REQUESTS
// -------------------------------------------------------------------------

func TestQueryHTTPRequests_Success(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		verifyAuthHeader(t, r)

		resp := graphQLResponse{
			Data: mustMarshal(t, httpRequestResponse{
				Viewer: struct {
					Zones []struct {
						HTTPRequestsAdaptiveGroups []HTTPRequestGroup `json:"httpRequestsAdaptiveGroups"`
					} `json:"zones"`
				}{
					Zones: []struct {
						HTTPRequestsAdaptiveGroups []HTTPRequestGroup `json:"httpRequestsAdaptiveGroups"`
					}{
						{
							HTTPRequestsAdaptiveGroups: []HTTPRequestGroup{
								{
									Count: 42,
									Dimensions: HTTPRequestDimensions{
										Datetime:                    "2026-03-13T10:00:00Z",
										ClientRequestHTTPMethodName: "GET",
										EdgeResponseStatus:          200,
									},
									Sum: HTTPRequestSum{
										EdgeResponseBytes: 1024,
									},
								},
							},
						},
					},
				},
			}),
		}
		writeJSON(t, w, resp)
	}))
	t.Cleanup(ts.Close)

	client := newTestClient(ts.URL, "test-token", "test-zone")

	groups, err := client.QueryHTTPRequests(context.Background(),
		time.Now().Add(-1*time.Hour), time.Now())
	if err != nil {
		t.Fatalf("QueryHTTPRequests() error = %v", err)
	}

	if len(groups) != 1 {
		t.Fatalf("got %d groups, want 1", len(groups))
	}
	if groups[0].Count != 42 {
		t.Errorf("count = %d, want 42", groups[0].Count)
	}
	if groups[0].Sum.EdgeResponseBytes != 1024 {
		t.Errorf("edgeResponseBytes = %d, want 1024", groups[0].Sum.EdgeResponseBytes)
	}
}

// -------------------------------------------------------------------------
// ERROR HANDLING
// -------------------------------------------------------------------------

func TestDoQuery_GraphQLError(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"data":null,"errors":[{"message":"zone not found"}]}`))
	}))
	t.Cleanup(ts.Close)

	client := newTestClient(ts.URL, "test-token", "bad-zone")

	_, err := client.QueryFirewallEvents(context.Background(),
		time.Now().Add(-1*time.Hour), time.Now())
	if err == nil {
		t.Error("expected error for GraphQL error response")
	}
}

func TestDoQuery_HTTPError(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"errors":[{"message":"unauthorized"}]}`))
	}))
	t.Cleanup(ts.Close)

	client := newTestClient(ts.URL, "bad-token", "test-zone")

	_, err := client.QueryFirewallEvents(context.Background(),
		time.Now().Add(-1*time.Hour), time.Now())
	if err == nil {
		t.Error("expected error for HTTP 401")
	}
}

func TestDoQuery_InvalidJSON(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`not json`))
	}))
	t.Cleanup(ts.Close)

	client := newTestClient(ts.URL, "test-token", "test-zone")

	_, err := client.QueryFirewallEvents(context.Background(),
		time.Now().Add(-1*time.Hour), time.Now())
	if err == nil {
		t.Error("expected error for invalid JSON response")
	}
}

func TestDoQuery_ServerDown(t *testing.T) {
	client := newTestClient("http://localhost:1", "test-token", "test-zone")

	_, err := client.QueryFirewallEvents(context.Background(),
		time.Now().Add(-1*time.Hour), time.Now())
	if err == nil {
		t.Error("expected error when server is unreachable")
	}
}

func TestDoQuery_RequestBody(t *testing.T) {
	var receivedBody []byte
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var err error
		receivedBody, err = io.ReadAll(r.Body)
		if err != nil {
			t.Fatal(err)
		}

		resp := graphQLResponse{
			Data: mustMarshal(t, firewallResponse{}),
		}
		writeJSON(t, w, resp)
	}))
	t.Cleanup(ts.Close)

	client := newTestClient(ts.URL, "test-token", "my-zone")

	_, _ = client.QueryFirewallEvents(context.Background(),
		time.Date(2026, 3, 13, 10, 0, 0, 0, time.UTC),
		time.Date(2026, 3, 13, 11, 0, 0, 0, time.UTC))

	var req graphQLRequest
	if err := json.Unmarshal(receivedBody, &req); err != nil {
		t.Fatalf("unmarshal request body: %v", err)
	}

	if req.Variables["zoneId"] != "my-zone" {
		t.Errorf("zoneId = %q, want %q", req.Variables["zoneId"], "my-zone")
	}
	if req.Variables["since"] != "2026-03-13T10:00:00Z" {
		t.Errorf("since = %q, want %q", req.Variables["since"], "2026-03-13T10:00:00Z")
	}
}

// -------------------------------------------------------------------------
// HELPERS
// -------------------------------------------------------------------------

// newTestClient creates a Client pointing at the given test server URL.
func newTestClient(url, token, zone string) *Client {
	c := NewClient(token, zone)
	c.httpClient = &http.Client{Timeout: 5 * time.Second}
	// --- Override the endpoint to point at httptest server ---
	c.endpoint = url
	return c
}

// verifyAuthHeader checks the Authorization header is a Bearer token.
func verifyAuthHeader(t *testing.T, r *http.Request) {
	t.Helper()
	auth := r.Header.Get("Authorization")
	if auth == "" {
		t.Error("missing Authorization header")
	}
}

// verifyContentType checks the Content-Type header is application/json.
func verifyContentType(t *testing.T, r *http.Request) {
	t.Helper()
	ct := r.Header.Get("Content-Type")
	if ct != "application/json" {
		t.Errorf("Content-Type = %q, want %q", ct, "application/json")
	}
}

// writeJSON encodes v as JSON and writes it to w, failing the test on error.
func writeJSON(t *testing.T, w http.ResponseWriter, v any) {
	t.Helper()
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(v); err != nil {
		t.Fatalf("json encode: %v", err)
	}
}

// mustMarshal serializes v to a json.RawMessage, failing the test on error.
func mustMarshal(t *testing.T, v any) json.RawMessage {
	t.Helper()
	data, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("json.Marshal: %v", err)
	}
	return data
}
