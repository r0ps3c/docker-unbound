# Unbound DNS Docker Image

[![Build and Tag](https://github.com/yourusername/docker-unbound/actions/workflows/build-and-tag.yml/badge.svg)](https://github.com/yourusername/docker-unbound/actions/workflows/build-and-tag.yml)

Lightweight, production-ready Docker image for [Unbound](https://nlnetlabs.nl/projects/unbound/) DNS resolver, built on Alpine Linux.

## Features

- **Minimal footprint**: Alpine-based image (~12MB)
- **Secure by default**: Non-root user, pinned base image, localhost-only configuration
- **Security scanning**: Automated Trivy vulnerability scanning
- **Auto-updates**: Renovate dependency management with 2-day stabilization period
- **Comprehensive testing**: Structure, standalone, and integration test suites (40 tests)
- **Multi-tag strategy**: Flexible image versioning
- **Automated workflows**: CI/CD with GitHub Actions

## Quick Start

```bash
# Run Unbound DNS server
docker run -d \
  --name unbound \
  -p 53:53/udp \
  -p 53:53/tcp \
  ghcr.io/yourusername/docker-unbound:latest

# Test DNS resolution
nslookup google.com 127.0.0.1
```

## Image Tags

- **`latest`** - Latest build from main branch
  - Updates: Automatically on every Unbound release
  - Use for: Testing, development

- **`stable`** - Production-ready stable release
  - Updates: Automatically for minor/patch versions; requires PR approval for major versions
  - Use for: Production deployments requiring stability with automatic security/bug fixes

- **`1.24.2`** (full version) - Immutable version tag
  - Updates: Never (immutable)
  - Use for: Reproducible builds, version pinning

- **`1`** (major version) - Latest within major version
  - Updates: Automatically for minor/patch versions within major version
  - Use for: Production deployments accepting minor updates

## Configuration

### Default Security Posture

The image uses Unbound's default configuration for security:
- **Listening**: localhost only (127.0.0.1 and ::1)
- **Access control**: localhost only
- **Recommended for**: Direct host usage, single-container deployments

### Network Configuration

For container networking (Docker networks, Kubernetes), mount a custom configuration:

```bash
docker run -d \
  --name unbound \
  -p 53:53/udp \
  -v /path/to/unbound.conf:/etc/unbound/unbound.conf:ro \
  ghcr.io/yourusername/docker-unbound:stable
```

**Example configuration for container networks:**
```yaml
server:
  interface: 0.0.0.0
  interface: ::0

  # Restrict to Docker networks only
  access-control: 10.0.0.0/8 allow
  access-control: 172.16.0.0/12 allow
  access-control: 192.168.0.0/16 allow
  access-control: 0.0.0.0/0 refuse
```

See [tests/configs/unbound-test.conf](tests/configs/unbound-test.conf) for a complete example.

## Testing

The image includes comprehensive test suites:

```bash
# Run all tests
make test-all

# Run individual test suites
make test-structure    # Image structure validation
make test-standalone   # Runtime functionality
make test-integration  # DNS query testing
```

See [tests/README.md](tests/README.md) for detailed testing documentation.

## Development

### Building Locally

```bash
# Build image
make build

# Extract version
make show-version

# Clean test resources
make clean-test
```

### Prerequisites

See [DEPENDENCIES.md](DEPENDENCIES.md) for setup requirements.

## Architecture

### Version Management

- **Version Source**: Unbound package version from Alpine Linux
- **Tagging Strategy**: Semantic versioning based on Unbound version
- **Stable Promotion**: Manual approval required for major version changes

### Automated Workflows

1. **Build and Tag** (`build-and-tag.yml`)
   - Triggers: Push to main/stable, PRs, manual
   - Actions: Build, test, version extraction, multi-tag push

2. **Check Updates** (`check-updates.yml`)
   - Triggers: Daily at 2 AM UTC, manual
   - Actions: Compare Alpine Unbound version, trigger build if changed

3. **Major Version Bump** (`check-major-version-bump.yml`)
   - Triggers: After successful build on main
   - Actions: Create PR to stable if major version differs

## License

MIT License - see [LICENSE](LICENSE)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Submit a pull request

All PRs must pass:
- Structure tests
- Standalone tests
- Integration tests
- Lint checks

## Resources

- [Unbound Documentation](https://nlnetlabs.nl/documentation/unbound/)
- [Issue Tracker](https://github.com/yourusername/docker-unbound/issues)
- [Changelog](https://github.com/yourusername/docker-unbound/releases)
