package main

import (
	"os"

	// Cloudflare CDKTF generated providers and resources
	"cdk.tf/go/stack/generated/cloudflare/cloudflare/dnsrecord"
	"cdk.tf/go/stack/generated/cloudflare/cloudflare/provider"
	"cdk.tf/go/stack/generated/cloudflare/cloudflare/zone"

	// JSII runtime and CDKTF core
	"github.com/aws/jsii-runtime-go"
	"github.com/hashicorp/terraform-cdk-go/cdktf"
)

// main is the entry point for the CDKTF application.
// It configures the Cloudflare provider, creates a DNS zone, and adds a subdomain A record.
func main() {
	// Initialize the CDKTF application
	app := cdktf.NewApp(nil)

	// Create a new Terraform stack
	stack := cdktf.NewTerraformStack(app, jsii.String("cf"))

	// --- Provider Configuration ---
	// Configure the Cloudflare provider with an API token.
	// TODO: Move sensitive values like API tokens to environment variables or a secrets manager.
	provider.NewCloudflareProvider(stack, jsii.String("cloudflare-provider"), &provider.CloudflareProviderConfig{
		ApiToken: jsii.String(os.Getenv("CLOUDFLARE_API_TOKEN")),
	})

	// --- Zone Resource ---
	// Define the Cloudflare DNS zone for the domain.
	zone := zone.NewZone(stack, jsii.String("alexanddakota_com"), &zone.ZoneConfig{
		Account: &zone.ZoneAccount{Id: jsii.String("023e105f4ecef8ad9ca31a8372d0c353")},
		Name:    jsii.String("alexanddakota.com"),
		Type:    jsii.String("full"),
	})

	// --- DNS Record Resource ---
	// Create an A record for the 'traefik' subdomain.
	dnsrecord.NewDnsRecord(stack, jsii.String("traefik_subdomain"), &dnsrecord.DnsRecordConfig{
		ZoneId:    zone.Id(),
		Name:      jsii.String("traefik"),
		Content:   jsii.String("91.90.126.102"),
		Type:      jsii.String("A"),
		Ttl:       jsii.Number(3600),
		Proxied:   jsii.Bool(false),
		DependsOn: &[]cdktf.ITerraformDependable{zone},
	})

	// Synthesize the Terraform configuration
	app.Synth()
}
