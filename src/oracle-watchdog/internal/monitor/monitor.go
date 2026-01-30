// -------------------------------------------------------------------------------
// Oracle Watchdog - Monitor Mode
//
// Project: Munchbox / Author: Alex Freidah
//
// Runs on each Oracle node and maintains a Consul session with TTL. The session
// acts as a heartbeat - if the node becomes unresponsive (due to Oracle
// reclamation), the session expires and the agent detects it.
//
// Self-healing design: never crashes due to Consul unavailability. Continuously
// attempts reconnection and emits metrics on current state.
// -------------------------------------------------------------------------------

package monitor

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"sync"
	"time"

	consul "github.com/hashicorp/consul/api"

	"github.com/afreidah/oracle-watchdog/internal/metrics"
)

const (
	sessionTTL     = "30s"
	renewInterval  = 10 * time.Second
	sessionKeyPath = "oracle-watchdog/nodes"
	metricsPort    = ":9104"
)

// -------------------------------------------------------------------------
// MONITOR STATE
// -------------------------------------------------------------------------

type state int

const (
	stateDisconnected state = iota
	stateConnecting
	stateActive
)

func (s state) String() string {
	switch s {
	case stateDisconnected:
		return "disconnected"
	case stateConnecting:
		return "connecting"
	case stateActive:
		return "active"
	default:
		return "unknown"
	}
}

// -------------------------------------------------------------------------
// MONITOR
// -------------------------------------------------------------------------

// Monitor maintains a Consul session heartbeat for an Oracle node.
type Monitor struct {
	nodeName      string
	consulAddress string

	mu        sync.RWMutex
	client    *consul.Client
	sessionID string
	state     state
}

// New creates a Monitor for the given node name. Always succeeds - connection
// to Consul happens asynchronously in Run().
func New(nodeName string) (*Monitor, error) {
	consulAddr := "consul.service.consul:8500"
	if addr := os.Getenv("CONSUL_HTTP_ADDR"); addr != "" {
		consulAddr = addr
	}

	return &Monitor{
		nodeName:      nodeName,
		consulAddress: consulAddr,
		state:         stateDisconnected,
	}, nil
}

// Run starts the monitor loop. Never returns an error due to Consul issues -
// continuously retries and emits metrics. Only returns on context cancellation.
func (m *Monitor) Run(ctx context.Context) error {
	metrics.RegisterMonitor()
	go metrics.Serve(ctx, metricsPort)

	ticker := time.NewTicker(renewInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			m.cleanup()
			return nil
		case <-ticker.C:
			m.tick(ctx)
		}
	}
}

func (m *Monitor) tick(_ context.Context) {
	m.mu.Lock()
	currentState := m.state
	m.mu.Unlock()

	switch currentState {
	case stateDisconnected:
		m.tryConnect()
	case stateConnecting:
		m.tryCreateSession()
	case stateActive:
		m.tryRenew()
	}
}

// -------------------------------------------------------------------------
// STATE TRANSITIONS
// -------------------------------------------------------------------------

func (m *Monitor) tryConnect() {
	metrics.MonitorReconnectAttempts.Inc()

	cfg := consul.DefaultConfig()
	cfg.Address = m.consulAddress

	client, err := consul.NewClient(cfg)
	if err != nil {
		slog.Warn("failed to create consul client", "error", err, "address", m.consulAddress)
		metrics.MonitorSessionFailures.Inc()
		return
	}

	// --- Verify connectivity with a simple operation ---
	_, err = client.Status().Leader()
	if err != nil {
		slog.Warn("consul not reachable", "error", err, "address", m.consulAddress)
		metrics.MonitorSessionFailures.Inc()
		return
	}

	m.mu.Lock()
	m.client = client
	m.state = stateConnecting
	m.mu.Unlock()

	metrics.MonitorConsulConnected.Set(1)
	slog.Info("connected to consul", "address", m.consulAddress)

	// --- Immediately try to create session ---
	m.tryCreateSession()
}

func (m *Monitor) tryCreateSession() {
	m.mu.RLock()
	client := m.client
	m.mu.RUnlock()

	if client == nil {
		m.transitionTo(stateDisconnected)
		return
	}

	entry := &consul.SessionEntry{
		Name:      fmt.Sprintf("oracle-watchdog/%s", m.nodeName),
		TTL:       sessionTTL,
		Behavior:  consul.SessionBehaviorDelete,
		LockDelay: 0,
	}

	sessionID, _, err := client.Session().Create(entry, nil)
	if err != nil {
		slog.Warn("failed to create session", "error", err)
		metrics.MonitorSessionFailures.Inc()
		m.transitionTo(stateDisconnected)
		metrics.MonitorConsulConnected.Set(0)
		return
	}

	// --- Write key associated with session ---
	if err := m.writeKey(client, sessionID); err != nil {
		slog.Warn("failed to write key", "error", err)
		metrics.MonitorSessionFailures.Inc()
		_, _ = client.Session().Destroy(sessionID, nil)
		m.transitionTo(stateDisconnected)
		metrics.MonitorConsulConnected.Set(0)
		return
	}

	m.mu.Lock()
	m.sessionID = sessionID
	m.state = stateActive
	m.mu.Unlock()

	metrics.MonitorSessionActive.Set(1)
	slog.Info("session created", "session_id", sessionID, "node", m.nodeName)
}

func (m *Monitor) tryRenew() {
	m.mu.RLock()
	client := m.client
	sessionID := m.sessionID
	m.mu.RUnlock()

	if client == nil || sessionID == "" {
		m.transitionTo(stateDisconnected)
		return
	}

	entry, _, err := client.Session().Renew(sessionID, nil)
	if err != nil || entry == nil {
		slog.Warn("session renewal failed", "error", err, "session_id", sessionID)
		metrics.MonitorSessionFailures.Inc()
		metrics.MonitorSessionActive.Set(0)
		m.transitionTo(stateConnecting)
		return
	}

	metrics.MonitorSessionRenewals.Inc()
	slog.Debug("session renewed", "session_id", sessionID)
}

func (m *Monitor) transitionTo(newState state) {
	m.mu.Lock()
	oldState := m.state
	m.state = newState

	if newState == stateDisconnected {
		m.client = nil
		m.sessionID = ""
		metrics.MonitorConsulConnected.Set(0)
		metrics.MonitorSessionActive.Set(0)
	}

	m.mu.Unlock()

	if oldState != newState {
		slog.Info("state transition", "from", oldState, "to", newState)
	}
}

func (m *Monitor) writeKey(client *consul.Client, sessionID string) error {
	kv := client.KV()
	key := fmt.Sprintf("%s/%s", sessionKeyPath, m.nodeName)

	pair := &consul.KVPair{
		Key:     key,
		Value:   []byte(time.Now().UTC().Format(time.RFC3339)),
		Session: sessionID,
	}

	acquired, _, err := kv.Acquire(pair, nil)
	if err != nil {
		return err
	}
	if !acquired {
		return fmt.Errorf("failed to acquire key lock")
	}

	slog.Debug("key written", "key", key)
	return nil
}

func (m *Monitor) cleanup() {
	m.mu.Lock()
	client := m.client
	sessionID := m.sessionID
	m.mu.Unlock()

	if client != nil && sessionID != "" {
		slog.Info("destroying session", "session_id", sessionID)
		_, _ = client.Session().Destroy(sessionID, nil)
	}

	metrics.MonitorSessionActive.Set(0)
	metrics.MonitorConsulConnected.Set(0)
}
