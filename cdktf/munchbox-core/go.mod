module cdk.tf/go/stack

go 1.23.0

toolchain go1.24.3

require github.com/aws/constructs-go/constructs/v10 v10.4.2

require github.com/hashicorp/terraform-cdk-go/cdktf v0.21.0

require github.com/aws/jsii-runtime-go v1.112.0

require (
	github.com/Masterminds/semver/v3 v3.3.1 // indirect
	github.com/fatih/color v1.18.0 // indirect
	github.com/mattn/go-colorable v0.1.13 // indirect
	github.com/mattn/go-isatty v0.0.20 // indirect
	github.com/yuin/goldmark v1.4.13 // indirect
	golang.org/x/lint v0.0.0-20210508222113-6edffad5e616 // indirect
	golang.org/x/mod v0.24.0 // indirect
	golang.org/x/sync v0.14.0 // indirect
	golang.org/x/sys v0.33.0 // indirect
	golang.org/x/tools v0.33.0 // indirect
)

replace cdk.tf/go/stack/generated/hashicorp/vault/provider => ./generated/hashicorp/vault/provider
