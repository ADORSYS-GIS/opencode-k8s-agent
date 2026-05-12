# Contributing to OpenCode K8s Agent

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to the project.

## Ways to Contribute

- 🐛 Report bugs and issues
- 💡 Suggest new features or improvements
- 📝 Improve documentation
- 🔧 Submit bug fixes
- ✨ Add new features
- 📊 Share custom prompts and configurations
- 🎨 Improve examples

## Getting Started

### Prerequisites

- Kubernetes cluster (kind, minikube, or cloud provider)
- Helm 3.0+
- kubectl configured
- Git

### Development Setup

1. **Fork and clone the repository**

```bash
git clone https://github.com/your-username/opencode-k8s-agent
cd opencode-k8s-agent
```

2. **Create a development cluster** (optional)

```bash
kind create cluster --name opencode-dev
```

3. **Install dependencies**

```bash
cd helm/opencode-k8s-agent
helm dependency update
```

4. **Make your changes**

Edit files in:
- `helm/opencode-k8s-agent/` - Chart files
- `helm/opencode-k8s-agent/files/` - Default configuration files
- `helm/opencode-k8s-agent/templates/` - Helm templates

5. **Test your changes**

```bash
# Lint the chart
helm lint .

# Template and verify
helm template test . --debug

# Install in test cluster
helm install test . --dry-run --debug
```

6. **Commit and push**

```bash
git add .
git commit -m "feat: add new feature"
git push origin feature-branch
```

7. **Open a Pull Request**

## Contribution Guidelines

### Code Style

- **YAML**: Use 2-space indentation
- **Bash**: Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- **Markdown**: Use [markdownlint](https://github.com/DavidAnson/markdownlint) rules
- **JSON**: Use 2-space indentation, no trailing commas

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `chore:` - Maintenance tasks
- `refactor:` - Code refactoring
- `test:` - Test additions or changes

Examples:
```
feat: add support for Slack notifications
fix: correct RBAC permissions for custom resources
docs: improve installation instructions
chore: update dependencies to latest versions
```

### Pull Request Process

1. **Update documentation** - If you change functionality, update README.md
2. **Add examples** - If you add features, provide usage examples
3. **Test thoroughly** - Ensure your changes work in a real cluster
4. **Update CHANGELOG** - Add your changes to CHANGELOG.md
5. **Request review** - Tag maintainers for review

### Testing Checklist

Before submitting a PR, verify:

- [ ] `helm lint .` passes without errors
- [ ] `helm template test .` generates valid YAML
- [ ] Chart installs successfully in a test cluster
- [ ] CronJob creates and runs successfully
- [ ] Reports are generated and sent to notifications
- [ ] Documentation is updated
- [ ] Examples are provided (if applicable)

## Sharing Custom Prompts

We encourage sharing custom prompts for different use cases!

### Prompt Contribution Process

1. **Create a new file** in `examples/prompts/`

```bash
examples/prompts/
├── cost-optimization.md
├── security-audit.md
├── compliance-monitoring.md
└── your-use-case.md  # Your new prompt
```

2. **Use the template**

```markdown
# [Use Case Name]

> Brief description of what this prompt does

## Use Case

Describe when and why someone would use this prompt.

## Configuration

### Prompt

\`\`\`markdown
[Your prompt content here]
\`\`\`

### Required RBAC Permissions

List any additional RBAC permissions needed:

\`\`\`yaml
rbac:
  clusterRole:
    rules:
      - apiGroups: ["example.io"]
        resources: ["customresources"]
        verbs: [get, list, watch]
\`\`\`

### Environment Variables

List any additional environment variables:

| Variable | Description | Required |
|----------|-------------|----------|
| `CUSTOM_VAR` | Description | Yes |

## Example Output

Show what the report looks like:

\`\`\`
# Executive Summary
...
\`\`\`

## Installation

\`\`\`bash
helm install opencode-k8s-agent ./helm/opencode-k8s-agent -f examples/prompts/your-use-case-values.yaml
\`\`\`

## Author

- Name: Your Name
- GitHub: @yourusername
- Date: 2024-01-01
```

3. **Create a values file**

```yaml
# examples/prompts/your-use-case-values.yaml
configMaps:
  runtime:
    prompt.md: |
      [Your prompt content]
```

4. **Test it**

```bash
helm install test ./helm/opencode-k8s-agent -f examples/prompts/your-use-case-values.yaml
kubectl create job --from=cronjob/test-opencode-k8s-agent manual-test
kubectl logs -f job/manual-test
```

5. **Submit PR**

Include:
- The prompt file
- The values file
- A screenshot or example of the output
- Description of the use case

## Reporting Bugs

### Before Reporting

1. Check [existing issues](https://github.com/ADORSYS-GIS/opencode-k8s-agent/issues)
2. Try the latest version
3. Review the [Troubleshooting](README.md#troubleshooting) section

### Bug Report Template

```markdown
**Describe the bug**
A clear description of what the bug is.

**To Reproduce**
Steps to reproduce:
1. Install chart with '...'
2. Run '...'
3. See error

**Expected behavior**
What you expected to happen.

**Actual behavior**
What actually happened.

**Environment**
- Kubernetes version: [e.g., 1.28]
- Helm version: [e.g., 3.12]
- Chart version: [e.g., 0.1.0]
- Cloud provider: [e.g., AWS EKS, GKE, on-prem]

**Logs**
```
[Paste relevant logs here]
```

**Configuration**
```yaml
[Paste your values.yaml here, redact secrets]
```

**Additional context**
Any other relevant information.
```

## Feature Requests

### Feature Request Template

```markdown
**Is your feature request related to a problem?**
A clear description of the problem.

**Describe the solution you'd like**
What you want to happen.

**Describe alternatives you've considered**
Other solutions you've thought about.

**Use case**
Describe your specific use case.

**Additional context**
Any other relevant information, mockups, examples.
```

## Documentation Improvements

Documentation improvements are always welcome!

### Areas to Improve

- Clarify confusing sections
- Add more examples
- Fix typos and grammar
- Improve formatting
- Add diagrams and visuals
- Translate to other languages

### Documentation Structure

```
helm/opencode-k8s-agent/
├── README.md              # Main documentation
├── CONTRIBUTING.md        # This file
├── CHANGELOG.md          # Version history
├── examples/             # Usage examples
│   ├── basic/
│   ├── production/
│   ├── multi-cluster/
│   └── prompts/
└── docs/                 # Additional documentation
    ├── architecture.md
    ├── security.md
    └── troubleshooting.md
```

## Code Review Process

### For Contributors

- Be responsive to feedback
- Make requested changes promptly
- Ask questions if feedback is unclear
- Be patient - reviews take time

### For Reviewers

- Be respectful and constructive
- Explain the "why" behind suggestions
- Approve when ready, request changes when needed
- Test the changes if possible

## Release Process

(For maintainers)

1. **Update version** in `Chart.yaml`
2. **Update CHANGELOG.md** with changes
3. **Create git tag**
   ```bash
   git tag -a v0.2.0 -m "Release v0.2.0"
   git push origin v0.2.0
   ```
4. **Package chart**
   ```bash
   helm package helm/opencode-k8s-agent
   ```
5. **Update Helm repository**
6. **Create GitHub release** with notes

## Community

### Communication Channels

- **GitHub Discussions**: General questions and discussions
- **GitHub Issues**: Bug reports and feature requests
- **Pull Requests**: Code contributions

### Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Focus on constructive feedback
- Assume good intentions
- No harassment or discrimination

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md
- Mentioned in release notes
- Credited in documentation (for significant contributions)

## Questions?

If you have questions about contributing:

1. Check this document
2. Search [GitHub Discussions](https://github.com/ADORSYS-GIS/opencode-k8s-agent/discussions)
3. Open a new discussion
4. Reach out to maintainers

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.

---

Thank you for contributing to OpenCode K8s Agent! 🎉
