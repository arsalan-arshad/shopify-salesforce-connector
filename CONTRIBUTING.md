# Contributing to Universal Shopify ↔ Salesforce Connector

Thank you for contributing to the **Universal Shopify ↔ Salesforce Connector** project! We welcome contributions from Salesforce developers, Shopify app engineers, integration architects, and admins to help keep this horizontal connector zero-cost, high-performance, and enterprise-grade.

---

## 🛠️ Local Development & Setup

### 1. Prerequisites

- [Salesforce CLI (`sf`)](https://developer.salesforce.com/tools/salesforce-cli) installed.
- [Node.js](https://nodejs.org/) (v20+ recommended).
- A free [Salesforce Developer Edition Org](https://developer.salesforce.com/signup) or Dev Hub.
- A Shopify Partner account or development store.

### 2. Development Workflow

#### Option A: Native Salesforce Setup (Apex REST Webhooks)

1. Authorize your Dev Hub or Developer Org:
   ```bash
   sf org login web -d -a my-dev-org
   ```
2. Create a scratch org (or use developer org):
   ```bash
   sf org create scratch -f config/project-scratch-def.json -a shopify-dev -d 7
   ```
3. Deploy Salesforce metadata:
   ```bash
   sf project deploy start
   ```
4. Assign the Administrator permission set:
   ```bash
   sf org assign permset -n Shopify_Connector_Admin
   ```
5. Run Apex unit tests with code coverage:
   ```bash
   sf apex run test --class-names ShopifyWebhookRestServiceTest ShopifySyncServiceTest ShopifyFulfillmentServiceTest ShopifyDLQServiceTest ShopifyConnectorControllerTest --code-coverage --result-format human
   ```

#### Option B: Standalone Node.js Webhook Gateway

1. Install dependencies:
   ```bash
   npm install
   ```
2. Copy environment template:
   ```bash
   cp .env.example .env
   ```
3. Run local unit tests:
   ```bash
   npm test
   ```
4. Start development gateway:
   ```bash
   npm run dev
   ```

---

## 📋 Pull Request (PR) & Coding Guidelines

1. **Keep PRs Focused:** Submit one bug fix, optimization, or feature per PR.
2. **Cryptographic Security & Verification:**
   - All inbound Shopify webhook handlers must verify HMAC-SHA256 signatures using timing-attack safe comparison.
   - Never log raw shared secrets or API tokens to `Shopify_Sync_Log__c`.
3. **Apex Architecture Standards:**
   - Strict `with sharing` enforcement on all classes.
   - Enforce user mode CRUD/FLS (`WITH USER_MODE` / `as user`).
   - Bulk-safe architecture (zero SOQL/DML queries inside loops).
   - Target $\ge 85\%$ Apex code coverage with positive, negative, and bulk assert statements.
4. **Dead-Letter Queue (DLQ) Resilience:**
   - Any transient sync errors must be caught and persisted to `Shopify_Sync_Log__c` with status `Failed` and stored payload for replay.
5. **Code Quality & Format Verification:**
   Before committing, always run:
   ```bash
   npm run lint
   npm run prettier:check
   npm test
   ```
6. **Main Branch Ruleset:**
   All PRs target `main` and require passing CI status checks and 1 approving review. See [`.github/RULESETS.md`](.github/RULESETS.md) for details.

---

## 🤝 Community & Security

- Please adhere to our [Code of Conduct](.github/CODE_OF_CONDUCT.md) in all discussions and reviews.
- For security vulnerabilities, please refer to our [Security Policy](.github/SECURITY.md) for responsible disclosure.
