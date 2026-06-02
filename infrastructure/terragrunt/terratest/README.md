# Munchbox terratest

Real-apply integration tests for `infrastructure/terragrunt/modules/*`.
Complements the plan-only `.tftest.hcl` suites that live next to each
module; this directory carries the Go tests that exercise the module
end-to-end against the **live** cluster (consul, vault, grafana, etc.).

## Layout

```
terratest/
├── go.mod                 # one module across every test package
├── Makefile               # make tidy / test / <module>
├── pkg/                   # shared helpers (sandbox prefixes, retry, ...)
└── <module_name>/         # one subdir per module under test
    └── <module>_test.go
```

## What each layer covers

| Layer                                          | Catches                                            |
| ---------------------------------------------- | -------------------------------------------------- |
| `modules/<m>/tests/*.tftest.hcl` (plan-only)   | input/output shape, `for_each` math, validation    |
| `terratest/<m>/` (this directory, real apply)  | provider-rejects-on-apply, schema drift, KV/state round-trip |
| `terragrunt apply` against the live cluster    | the actual change you're shipping                  |

## Running

```bash
source munchbox-env.sh        # provides CONSUL_HTTP_*, VAULT_*, etc.
cd infrastructure/terragrunt/terratest
make tidy                     # one-time, syncs go.sum
make test                     # run every package
make prometheus-alerts        # run just one
```

Tests skip themselves if their required env vars aren't set, so
running `make test` from a fresh shell without sourcing
`munchbox-env.sh` is a no-op (not a failure).

## Adding a new module test

1. `mkdir <module_name>` next to this README.
2. `cd <module_name> && touch <module_name>_test.go`. Use
   `package <module_name>_test` (Go external-test convention).
3. Add a `make <module_name>` target in `Makefile`.
4. Skip on missing env so `make test` stays safe from a clean shell.
5. Use a clearly-namespaced sandbox prefix/folder
   (`zz-terratest-<random>-...`) so accidental leaks are easy to clean
   up. `random.UniqueId()` from terratest is the standard generator.
