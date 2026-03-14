// -------------------------------------------------------------------------------
// Cloudflare GraphQL Client
//
// Author: Alex Freidah
//
// HTTP client for the Cloudflare GraphQL Analytics API. Queries firewall events
// and HTTP traffic statistics. Handles rate limiting, response parsing, and
// seek-based pagination via datetime filters.
// -------------------------------------------------------------------------------

package cloudflare

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/afreidah/cloudflare-log-collector/internal/telemetry"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
)

// graphQLEndpoint is the Cloudflare Analytics GraphQL API URL.
const graphQLEndpoint = "https://api.cloudflare.com/client/v4/graphql"

// -------------------------------------------------------------------------
// CLIENT
// -------------------------------------------------------------------------

// Client talks to the Cloudflare GraphQL Analytics API.
type Client struct {
	apiToken   string
	zoneID     string
	endpoint   string
	httpClient *http.Client
}

// NewClient creates a Cloudflare GraphQL client.
func NewClient(apiToken, zoneID string) *Client {
	return &Client{
		apiToken: apiToken,
		zoneID:   zoneID,
		endpoint: graphQLEndpoint,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// -------------------------------------------------------------------------
// RESPONSE TYPES
// -------------------------------------------------------------------------

// FirewallEvent represents a single firewall/WAF event from Cloudflare.
type FirewallEvent struct {
	Action                       string `json:"action"`
	ClientIP                     string `json:"clientIP"`
	ClientRequestHTTPHost        string `json:"clientRequestHTTPHost"`
	ClientRequestHTTPMethodName  string `json:"clientRequestHTTPMethodName"`
	ClientRequestPath            string `json:"clientRequestPath"`
	ClientRequestQuery           string `json:"clientRequestQuery"`
	Datetime                     string `json:"datetime"`
	RayName                      string `json:"rayName"`
	RuleID                       string `json:"ruleId"`
	Source                       string `json:"source"`
	UserAgent                    string `json:"userAgent"`
	ClientCountryName            string `json:"clientCountryName"`
}

// HTTPRequestGroup represents an aggregated HTTP traffic data point.
type HTTPRequestGroup struct {
	Count      int                    `json:"count"`
	Dimensions HTTPRequestDimensions  `json:"dimensions"`
	Sum        HTTPRequestSum         `json:"sum"`
}

// HTTPRequestDimensions holds the grouping dimensions for HTTP traffic.
type HTTPRequestDimensions struct {
	Datetime                    string `json:"datetime"`
	ClientRequestHTTPMethodName string `json:"clientRequestHTTPMethodName"`
	EdgeResponseStatus          int    `json:"edgeResponseStatus"`
	ClientCountryName           string `json:"clientCountryName"`
}

// HTTPRequestSum holds the aggregated byte counts for HTTP traffic.
type HTTPRequestSum struct {
	EdgeResponseBytes int64 `json:"edgeResponseBytes"`
}

// -------------------------------------------------------------------------
// GRAPHQL REQUEST / RESPONSE
// -------------------------------------------------------------------------

// graphQLRequest is the JSON payload sent to the Cloudflare GraphQL API.
type graphQLRequest struct {
	Query     string         `json:"query"`
	Variables map[string]any `json:"variables,omitempty"`
}

// graphQLResponse is the top-level envelope returned by the Cloudflare GraphQL API.
type graphQLResponse struct {
	Data   json.RawMessage `json:"data"`
	Errors []struct {
		Message string `json:"message"`
	} `json:"errors"`
}

// firewallResponse maps the GraphQL response for firewallEventsAdaptive queries.
type firewallResponse struct {
	Viewer struct {
		Zones []struct {
			FirewallEventsAdaptive []FirewallEvent `json:"firewallEventsAdaptive"`
		} `json:"zones"`
	} `json:"viewer"`
}

// httpRequestResponse maps the GraphQL response for httpRequestsAdaptiveGroups queries.
type httpRequestResponse struct {
	Viewer struct {
		Zones []struct {
			HTTPRequestsAdaptiveGroups []HTTPRequestGroup `json:"httpRequestsAdaptiveGroups"`
		} `json:"zones"`
	} `json:"viewer"`
}

// -------------------------------------------------------------------------
// QUERIES
// -------------------------------------------------------------------------

// firewallQuery fetches individual firewall/WAF events ordered by time.
const firewallQuery = `query ($zoneId: String!, $since: String!, $until: String!) {
  viewer {
    zones(filter: {zoneTag: $zoneId}) {
      firewallEventsAdaptive(
        filter: {datetime_gt: $since, datetime_leq: $until}
        limit: 10000
        orderBy: [datetime_ASC]
      ) {
        action clientIP clientRequestHTTPHost clientRequestHTTPMethodName
        clientRequestPath clientRequestQuery datetime rayName ruleId
        source userAgent clientCountryName
      }
    }
  }
}`

// httpRequestQuery fetches aggregated HTTP traffic grouped by method, status, and country.
const httpRequestQuery = `query ($zoneId: String!, $since: String!, $until: String!) {
  viewer {
    zones(filter: {zoneTag: $zoneId}) {
      httpRequestsAdaptiveGroups(
        filter: {datetime_gt: $since, datetime_leq: $until}
        limit: 5000
      ) {
        count
        dimensions {
          datetime
          clientRequestHTTPMethodName
          edgeResponseStatus
          clientCountryName
        }
        sum {
          edgeResponseBytes
        }
      }
    }
  }
}`

// -------------------------------------------------------------------------
// API METHODS
// -------------------------------------------------------------------------

// QueryFirewallEvents fetches firewall events in the given time range.
func (c *Client) QueryFirewallEvents(ctx context.Context, since, until time.Time) ([]FirewallEvent, error) {
	vars := map[string]any{
		"zoneId": c.zoneID,
		"since":  since.UTC().Format(time.RFC3339),
		"until":  until.UTC().Format(time.RFC3339),
	}

	body, err := c.doQuery(ctx, firewallQuery, vars)
	if err != nil {
		return nil, fmt.Errorf("firewall query: %w", err)
	}

	var resp firewallResponse
	if err := json.Unmarshal(body, &resp); err != nil {
		return nil, fmt.Errorf("firewall response parse: %w", err)
	}

	if len(resp.Viewer.Zones) == 0 {
		return nil, nil
	}

	return resp.Viewer.Zones[0].FirewallEventsAdaptive, nil
}

// QueryHTTPRequests fetches aggregated HTTP traffic stats in the given time range.
func (c *Client) QueryHTTPRequests(ctx context.Context, since, until time.Time) ([]HTTPRequestGroup, error) {
	vars := map[string]any{
		"zoneId": c.zoneID,
		"since":  since.UTC().Format(time.RFC3339),
		"until":  until.UTC().Format(time.RFC3339),
	}

	body, err := c.doQuery(ctx, httpRequestQuery, vars)
	if err != nil {
		return nil, fmt.Errorf("http request query: %w", err)
	}

	var resp httpRequestResponse
	if err := json.Unmarshal(body, &resp); err != nil {
		return nil, fmt.Errorf("http request response parse: %w", err)
	}

	if len(resp.Viewer.Zones) == 0 {
		return nil, nil
	}

	return resp.Viewer.Zones[0].HTTPRequestsAdaptiveGroups, nil
}

// -------------------------------------------------------------------------
// INTERNAL
// -------------------------------------------------------------------------

// doQuery sends a GraphQL request and returns the data field from the response.
func (c *Client) doQuery(ctx context.Context, query string, variables map[string]any) (json.RawMessage, error) {
	ctx, span := telemetry.StartSpan(ctx, "cloudflare.graphql",
		attribute.String("cflog.zone_id", c.zoneID),
	)
	defer span.End()

	reqBody := graphQLRequest{
		Query:     query,
		Variables: variables,
	}

	payload, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint, bytes.NewReader(payload))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.apiToken)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("http request: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	span.SetAttributes(attribute.Int("http.status_code", resp.StatusCode))

	if resp.StatusCode != http.StatusOK {
		err := fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(respBody))
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return nil, err
	}

	var gqlResp graphQLResponse
	if err := json.Unmarshal(respBody, &gqlResp); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return nil, fmt.Errorf("parse graphql response: %w", err)
	}

	if len(gqlResp.Errors) > 0 {
		err := fmt.Errorf("graphql error: %s", gqlResp.Errors[0].Message)
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return nil, err
	}

	return gqlResp.Data, nil
}
