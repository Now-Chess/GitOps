# Development and Contribution Guide

Guidelines for developing and contributing to the GitOps repository.

## Repository Workflow

### Setting Up Local Development

```bash
# Clone the repository
git clone git@git.janis-eccarius.de:NowChess/GitOps.git
cd GitOps

# Create feature branch
git checkout -b feature/my-feature

# Install development tools
brew install kubectl helm kustomize  # macOS
sudo apt-get install kubectl helm kustomize  # Linux
```

### Making Changes

1. **Validate locally**:
```bash
# Build manifests without applying
kustomize build <path> | kubectl apply --dry-run=client -f -

# Render templates
helm template -f values.yaml <chart>

# Validate manifests
kubeval <manifests>
```

2. **Test changes**:
```bash
# Apply to test cluster
kustomize build <path> | kubectl apply -f -

# Monitor deployment
kubectl get pods -A -w

# Check logs
kubectl logs -n <namespace> -l <selector> -f
```

3. **Commit changes**:
```bash
git add .
git commit -m "feat: describe your change"
git push origin feature/my-feature
```

## Commit Message Guidelines

Follow semantic versioning in commit messages:

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Code style changes
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Test changes
- `chore`: Build/dependency changes

Example:
```
feat(argocd): add OIDC authentication

Enable OIDC authentication for Argo CD with Azure AD integration.
This allows SSO for cluster access.

Closes #123
```

## Code Review Process

1. Create Merge Request (MR) with clear description
2. Reference related issues
3. Wait for code review
4. Address review comments
5. Merge after approval

### MR Template

```markdown
## Description
Brief description of changes

## Related Issues
Closes #123

## Changes Made
- Change 1
- Change 2

## Testing
- [x] Tested locally
- [x] Validated manifests
- [x] Checked for security issues

## Deployment Notes
Any special deployment considerations
```

## Directory Structure Guidelines

```
GitOps/
├── <component>/               # Tool or service
│   ├── base/                 # Base Kustomization
│   │   ├── kustomization.yaml
│   │   └── values.yaml
│   └── <region>/             # Regional overrides
│       ├── kustomization.yaml
│       └── values.yaml
├── <region>/                 # Regional apps
│   ├── root-apps-app.yaml
│   └── argo-apps/
│       └── <app>/
├── scripts/                  # Automation scripts
├── secrets/                  # Encrypted secrets
├── docs/                     # Documentation
└── README.md
```

## Best Practices

### 1. Keep Commits Small and Focused
- Each commit should represent one logical change
- Easier to review and revert if needed
- Better for git history and bisecting

### 2. Document Changes
- Update README for significant changes
- Add comments to complex configurations
- Document assumptions and dependencies

### 3. Version Everything
- Use explicit versions for Helm charts
- Pin container image tags
- Tag releases with semantic versioning

### 4. Security First
- Never commit unencrypted secrets
- Use Sealed Secrets for sensitive data
- Rotate credentials regularly
- Review access logs

### 5. Test Thoroughly
- Use dry-run before applying
- Test in non-production first
- Validate manifests with kubeval
- Monitor for side effects

### 6. Maintain Consistency
- Use consistent naming conventions
- Follow established patterns
- Align with Kubernetes best practices
- Use linting tools

## Testing Guidelines

### Manifest Validation

```bash
# Install kubeval
go install github.com/instrumenta/kubeval@latest

# Validate manifests
find . -name "*.yaml" -type f | xargs kubeval

# Validate with schema
kubeval -d "https://raw.githubusercontent.com/kubernetes/kubernetes/v1.26.0/api/openapi-schema/v3/apis__apps__v1__Deployment.json" deployment.yaml
```

### Kustomize Testing

```bash
# Build manifests
kustomize build . > manifests.yaml

# Verify structure
kustomize build . | head -50

# Test overlays
kustomize build overlays/test/
kustomize build overlays/prod/
```

### Manual Testing

```bash
# Create test namespace
kubectl create namespace test-deploy

# Apply manifests
kustomize build . | kubectl apply -n test-deploy -f -

# Verify deployment
kubectl -n test-deploy get all

# Clean up
kubectl delete namespace test-deploy
```

## Release Process

### Versioning Strategy

Use semantic versioning: `MAJOR.MINOR.PATCH`

- MAJOR: Breaking changes
- MINOR: New features
- PATCH: Bug fixes

### Creating a Release

```bash
# Create release branch
git checkout -b release/v1.2.0

# Update version in documentation
# Update CHANGELOG.md

# Commit version bump
git add .
git commit -m "chore: bump version to 1.2.0"

# Create tag
git tag -a v1.2.0 -m "Release version 1.2.0"

# Push tag
git push origin v1.2.0
git push origin release/v1.2.0
```

## Documentation Requirements

For all significant changes, update documentation:

- README.md: Overview and quick start
- ARCHITECTURE.md: System design changes
- DEPLOYMENT_GUIDE.md: Installation instructions
- CONFIGURATION.md: Configuration options
- TROUBLESHOOTING.md: Known issues and solutions

## Tools and Resources

### Recommended Tools

```bash
# Package managers
brew              # macOS
apt/apt-get       # Linux (Debian/Ubuntu)
choco             # Windows

# Kubernetes tools
kubectl
helm
kustomize
kubeval
kubeseal
k9s               # Terminal UI for Kubernetes

# Git tools
git
gh                # GitHub CLI
gitlab-cli        # GitLab CLI

# Editors
VSCode with Kubernetes extension
vim/neovim with LSP
```

### Useful VS Code Extensions

- Kubernetes
- YAML
- Docker
- Helm Intellisense
- GitLens

### Learning Resources

- Kubernetes Documentation: https://kubernetes.io/docs/
- Argo CD Documentation: https://argo-cd.readthedocs.io/
- Helm Documentation: https://helm.sh/docs/
- Kustomize Documentation: https://kustomize.io/
- GitOps Best Practices: https://www.gitops.tech/

## Troubleshooting Development Issues

### Common Development Problems

**Problem: Kustomize build fails**
```bash
# Check syntax
kustomize build . --dry-run

# Verbose output
kustomize build . -v
```

**Problem: Helm values not overriding**
```bash
# Check values order
helm template -f values.yaml -f overrides.yaml

# Use merge strategy
helmCharts:
- name: argo-cd
  valuesInline:
    key: value
```

**Problem: Changes not syncing in cluster**
```bash
# Force Argo CD sync
argocd app sync <app-name> --force

# Check for validation errors
kubectl describe application <app-name> -n argocd
```

## Contact and Support

For questions or issues:
- Create GitHub/GitLab issue
- Start discussion in repository
- Contact DevOps team
- Check existing documentation

---

**Last Updated**: 2026-04-16
**Contributing**: Follow this guide for all contributions

