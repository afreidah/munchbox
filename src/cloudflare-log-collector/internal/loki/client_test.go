// -------------------------------------------------------------------------------
// Loki Push Client Tests
//
// Author: Alex Freidah
//
// Tests for the Loki push API client using httptest servers to mock Loki
// responses. Covers successful pushes, error handling, empty batch skipping,
// and request payload verification.
// -------------------------------------------------------------------------------

package loki

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// -------------------------------------------------------------------------
// PUSH
// -------------------------------------------------------------------------

func TestPush_Success(t *testing.T) {
	var received pushRequest
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		verifyPushRequest(t, r)

		body, err := io.ReadAll(r.Body)
		if err != nil {
			t.Fatal(err)
		}
		if err := json.Unmarshal(body, &received); err != nil {
			t.Fatal(err)
		}

		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(ts.Close)

	client := NewClient(ts.URL, "fake")

	labels := map[string]string{"job": "test"}
	entries := []Entry{
		NewEntry(time.Now(), `{"msg":"hello"}`),
		NewEntry(time.Now(), `{"msg":"world"}`),
	}

	err := client.Push(context.Background(), labels, entries)
	if err != nil {
		t.Fatalf("Push() error = %v", err)
	}

	if len(received.Streams) != 1 {
		t.Fatalf("got %d streams, want 1", len(received.Streams))
	}
	if len(received.Streams[0].Values) != 2 {
		t.Fatalf("got %d values, want 2", len(received.Streams[0].Values))
	}
}

func TestPush_EmptyEntries(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("should not make HTTP request for empty entries")
	}))
	t.Cleanup(ts.Close)

	client := NewClient(ts.URL, "fake")

	err := client.Push(context.Background(), map[string]string{"job": "test"}, nil)
	if err != nil {
		t.Fatalf("Push() with empty entries should not error, got: %v", err)
	}
}

func TestPush_TenantHeader(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		orgID := r.Header.Get("X-Scope-OrgID")
		if orgID != "my-tenant" {
			t.Errorf("X-Scope-OrgID = %q, want %q", orgID, "my-tenant")
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(ts.Close)

	client := NewClient(ts.URL, "my-tenant")

	err := client.Push(context.Background(),
		map[string]string{"job": "test"},
		[]Entry{NewEntry(time.Now(), `{"msg":"test"}`)},
	)
	if err != nil {
		t.Fatalf("Push() error = %v", err)
	}
}

func TestPush_StreamLabels(t *testing.T) {
	var received pushRequest
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &received)
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(ts.Close)

	client := NewClient(ts.URL, "fake")

	labels := map[string]string{
		"job":  "cloudflare",
		"type": "firewall",
		"zone": "munchbox.cc",
	}

	err := client.Push(context.Background(), labels,
		[]Entry{NewEntry(time.Now(), `{}`)},
	)
	if err != nil {
		t.Fatalf("Push() error = %v", err)
	}

	if received.Streams[0].Stream["job"] != "cloudflare" {
		t.Errorf("stream label job = %q, want %q", received.Streams[0].Stream["job"], "cloudflare")
	}
	if received.Streams[0].Stream["type"] != "firewall" {
		t.Errorf("stream label type = %q, want %q", received.Streams[0].Stream["type"], "firewall")
	}
}

// -------------------------------------------------------------------------
// ERROR HANDLING
// -------------------------------------------------------------------------

func TestPush_ServerError(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte("internal error"))
	}))
	t.Cleanup(ts.Close)

	client := NewClient(ts.URL, "fake")

	err := client.Push(context.Background(),
		map[string]string{"job": "test"},
		[]Entry{NewEntry(time.Now(), `{}`)},
	)
	if err == nil {
		t.Error("expected error for HTTP 500")
	}
}

func TestPush_ServerDown(t *testing.T) {
	client := NewClient("http://localhost:1", "fake")

	err := client.Push(context.Background(),
		map[string]string{"job": "test"},
		[]Entry{NewEntry(time.Now(), `{}`)},
	)
	if err == nil {
		t.Error("expected error when server is unreachable")
	}
}

// -------------------------------------------------------------------------
// ENTRY
// -------------------------------------------------------------------------

func TestNewEntry_TimestampFormat(t *testing.T) {
	ts := time.Date(2026, 3, 13, 10, 30, 0, 0, time.UTC)
	entry := NewEntry(ts, `{"msg":"test"}`)

	if entry.Line != `{"msg":"test"}` {
		t.Errorf("line = %q, want %q", entry.Line, `{"msg":"test"}`)
	}

	// --- Timestamp should be nanoseconds since epoch ---
	want := fmt.Sprintf("%d", ts.UnixNano())
	if entry.Timestamp != want {
		t.Errorf("timestamp = %q, want %q", entry.Timestamp, want)
	}
}

// -------------------------------------------------------------------------
// HELPERS
// -------------------------------------------------------------------------

// verifyPushRequest checks that the HTTP request targets the correct path
// with the correct content type.
func verifyPushRequest(t *testing.T, r *http.Request) {
	t.Helper()

	if r.Method != http.MethodPost {
		t.Errorf("method = %q, want POST", r.Method)
	}
	if r.URL.Path != "/loki/api/v1/push" {
		t.Errorf("path = %q, want /loki/api/v1/push", r.URL.Path)
	}
	if ct := r.Header.Get("Content-Type"); ct != "application/json" {
		t.Errorf("Content-Type = %q, want application/json", ct)
	}
}
