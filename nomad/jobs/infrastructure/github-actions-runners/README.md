# GitHub Actions Runners

Self-hosted GitHub Actions CI runners using the munchbox-service pack. Runs
two instances with Docker socket passthrough for containerized builds.
Registration credentials come from Vault via workload identity. Excluded
from the Oracle Cloud node (mccoy) due to architecture constraints.
