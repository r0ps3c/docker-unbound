# Unbound DNS Docker Image

[![Build and Tag](https://github.com/r0ps3c/docker-unbound/actions/workflows/build-and-tag.yml/badge.svg)](https://github.com/r0ps3c/docker-unbound/actions/workflows/build-and-tag.yml)

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
  ghcr.io/r0ps3c/docker-unbound:latest

# Test DNS resolution
nslookup google.com 127.0.0.1
```

## Image Tags

- **`main`** - Latest build from main branch (same as `latest`)
- **`latest`** - Latest build from main branch (same as `main`)
- **`stable`** - Production-ready stable release; updated automatically for minor/patch versions; requires PR approval for major versions
- **`<major>.<minor>.<subminor>`** (full version) - Immutable version tag
  **`<major>`** (major version) - Latest within major version
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
  ghcr.io/r0ps3c/docker-unbound:stable
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

## License
MIT License - see [LICENSE](LICENSE)
