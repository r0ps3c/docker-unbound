# Dependencies and Setup

This document describes the setup requirements for building and testing the docker-unbound image.

## Required Tools

- **Docker** 20.10+
- **Make** (GNU Make 4.0+)
- **Git** 2.0+

Optional:
- **bind-tools** (nslookup, dig) for manual DNS testing

## Quick Start

```bash
# Build image
make build

# Run tests
make test-all
```

## GitHub Actions Setup

### Repository Permissions

Enable in repository settings:
1. **Actions** → Allow GitHub Actions
2. **Actions** → Workflow permissions → Read and write permissions
3. **Actions** → Allow GitHub Actions to create pull requests

### Branch Protection (Recommended)

For `stable` branch:
- Require pull request reviews (1 approver)
- Require status checks to pass
- Include administrators

## Renovate Setup

[Renovate](https://docs.renovatebot.com/) manages dependencies with a 2-day stabilization period.

**Manages:**
- Alpine base image
- Unbound APK package
- GitHub Actions

**Setup:**
1. Install [Renovate GitHub App](https://github.com/apps/renovate) on your repository
2. Repository Settings → Actions → General
   - Workflow permissions: "Read and write permissions"
   - Enable "Allow GitHub Actions to create and approve pull requests"
3. Repository Settings → General → Pull Requests
   - Enable "Allow auto-merge" (optional but recommended)
4. Merge the onboarding PR Renovate creates

**Auto-merge Behavior:**
- Minor/patch updates: Auto-merge after 2 days + tests pass
- Major updates: Manual review required

See `renovate.json` for configuration details.

## Security Scanning

Trivy scans run automatically:
- On push to main and pull requests
- Daily at 6 AM UTC
- Results in GitHub Security tab

Fails build only on fixable CRITICAL vulnerabilities.

## Troubleshooting

**Build fails - "Cannot connect to Docker daemon"**
- Check Docker service is running
- Add user to docker group: `sudo usermod -aG docker $USER`

**Tests fail - "Port already in use"**
- Stop service using port 53: `sudo lsof -i :53`
- Or edit tests to use different port

**Tests fail - "DNS resolution timeout"**
- Check host DNS works: `nslookup google.com`
- Verify Docker networking: `docker network create test-net && docker network rm test-net`

## Platform Support

- **Linux**: Native Docker (recommended)
- **macOS**: Docker Desktop
- **Windows**: Docker Desktop with WSL2

## Support

For issues:
1. Check troubleshooting above
2. Review [test documentation](tests/README.md)
3. Open an issue on GitHub
