# GitHub Branch Rulesets & Release Tag Lifecycle Maintenance

This document specifies the open-source engineering governance, branch protection rulesets, and release tag maintenance workflows for **Universal Shopify ↔ Salesforce Connector**.

---

## 🛡️ 1. Main Branch Ruleset Architecture

To maintain enterprise quality and open-source contribution integrity, the `main` branch is protected by a strict GitHub Repository Ruleset.

### Ruleset Configuration: `main-branch-protection`

- **Target Branch:** `refs/heads/main`
- **Enforcement Status:** `Active`
- **Specification File:** [`.github/rulesets/main-ruleset.json`](./rulesets/main-ruleset.json)

### Enforced Rules

| Rule                              | Enforcement Setting                                    | Rationale                                                      |
| :-------------------------------- | :----------------------------------------------------- | :------------------------------------------------------------- |
| **Pull Request Required**         | Minimum 1 approving review required                    | Prevents untested direct pushes to production branch.          |
| **Dismiss Stale Approvals**       | Enabled (`dismiss_stale_reviews_on_push: true`)        | Re-evaluates PR when contributors push additional code.        |
| **Require Thread Resolution**     | Enabled (`required_review_thread_resolution: true`)    | Ensures all code review discussions are resolved.              |
| **Linear History**                | Enabled (`required_linear_history: true`)              | Prevents messy merge bubbles; requires rebase or squash-merge. |
| **Block Force Pushes**            | Enabled (`non_fast_forward: true`)                     | Prevents rewriting git history.                                |
| **Block Branch Deletions**        | Enabled (`deletion: true`)                             | Protects repository baseline.                                  |
| **Strict Required Status Checks** | Enabled (`strict_required_status_checks_policy: true`) | Requires branch to be up to date before merging.               |

### Required CI Status Checks

Merges into `main` are blocked until both of the following CI jobs pass:

1. `Lint, Prettier & Node Unit Tests`: Verifies ESLint zero-error compliance, Prettier code style, and passes all Node.js HMAC gateway unit tests.
2. `Validate Salesforce Deployment & Apex Tests`: Verifies metadata deployability and validates Apex unit tests with $\ge 85\%$ test coverage.

---

## 🏷️ 2. Release Tag Maintenance & Semantic Versioning

This project adheres strictly to [Semantic Versioning 2.0.0](https://semver.org/) (`vMAJOR.MINOR.PATCH`).

### Version Alignment Matrix

When publishing a new release, versions across all configuration files must stay synchronized:

| File                | Field              | Example                                                      |
| :------------------ | :----------------- | :----------------------------------------------------------- |
| `package.json`      | `"version"`        | `"0.1.0"`                                                    |
| `sfdx-project.json` | `"versionNumber"`  | `"0.1.0.NEXT"`                                               |
| `sfdx-project.json` | `"packageAliases"` | `"ShopifySalesforceConnector@0.1.0-1": "04tg7000000XZWrAAO"` |
| Git Tag             | Tag Name           | `v0.1.0`                                                     |

### Step-by-Step Release Workflow

1. **Verify Local Quality Checks:**

   ```bash
   npm run lint
   npm run prettier:check
   npm test
   ```

2. **Prepare Release Commit:**
   Update `package.json` and `sfdx-project.json` version strings:

   ```bash
   git add package.json sfdx-project.json
   git commit -m "chore(release): prepare release v0.1.0"
   git push origin main
   ```

3. **Create Annotated Release Tag:**

   ```bash
   git tag -a v0.1.0 -m "Release v0.1.0: Universal Shopify ↔ Salesforce Connector"
   git push origin v0.1.0
   ```

4. **Automated Release Dispatch:**
   Pushing the `v*` tag triggers the GitHub Actions workflow [`.github/workflows/release.yml`](./workflows/release.yml), which:
   - Verifies tests across Node.js and Apex.
   - Creates an official GitHub Release.
   - Publishes 1-click 2GP package installation URLs for Production and Sandbox.
   - Formats and publishes release notes and changelog.

---

## 🤝 3. Contributor PR Lifecycle

1. Contributors fork the repository and create a feature branch (`feat/your-feature-name` or `fix/issue-description`).
2. Implement code adhering to SLDS design tokens, user mode security (`WITH USER_MODE`), and cryptographic HMAC verification.
3. Open a Pull Request targeting `main`.
4. Fill in the [Pull Request Template](./pull_request_template.md).
5. Address review feedback and verify passing CI status checks.
6. A maintainer squash-merges into `main`.
