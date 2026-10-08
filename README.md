# Universal Shopify ↔ Salesforce Connector

> **Open-Source (MIT)** | Built for the E-Commerce & Salesforce Developer Community | Part of the Salesforce Open-Source Ecosystem Portfolio

---

## 1. Overview & Vision
A 100% free, high-performance horizontal open-source integration bridge connecting Shopify storefronts with Salesforce CRM.

While existing enterprise tools (MuleSoft, Celigo) cost upwards of $10,000/year and basic middleware (Zapier, Make) charges per task execution, this connector provides a generous, zero-friction sync for core e-commerce data without expensive per-transaction fees.

---

## 2. Killer Differentiators & Features
- ⚡ **Zero Per-Task Pricing:** 100% open-source integration running on serverless/webhooks without middleware fees.
- 👤 **Customer $\rightarrow$ Contact & Account Sync:** Real-time ingestion on `customers/create` & `customers/update` with automatic de-duplication by email/phone.
- 🛍️ **Order $\rightarrow$ Order & Opportunity Sync:** Captures `orders/create` & `orders/paid`, mapping line items to Salesforce `PricebookEntry` and `OrderItem`.
- 🚨 **Abandoned Checkout $\rightarrow$ High-Priority Lead:** High-value abandoned carts ($> \$200$) automatically spawn a Salesforce `Lead` with a follow-up `Task`.
- 🔄 **Bi-directional Fulfillment Push:** Warehouse updates in Salesforce automatically push tracking numbers back to Shopify.
- 🛡️ **Dead-Letter Queue (DLQ) & Error Dashboard:** Custom object `Shopify_Sync_Log__c` tracks failed events with automated replay.

---

## 3. Standardized 4-Phase Delivery Roadmap

### 📋 Phase 1: Local Development & Differentiators
- [ ] Apex Webhook Ingestion REST endpoint / Platform Event schema.
- [ ] Custom Settings / Custom Metadata for field mapping.
- [ ] Sync Engine (`ShopifySyncService.cls`) handling customer, order, and line item transformations.
- [ ] Setup LWC (`shopifyConnectorConfig`) for configuring store credentials and field mappings.
- [ ] $\ge 85\%$ Apex unit test coverage with HTTP mock test classes.

### 📋 Phase 2: GitHub & Open-Source Engineering
- [ ] Git repository initialized: `github.com/arsalan-arshad/shopify-salesforce-connector`.
- [ ] Automated GitHub Actions CI workflow (`.github/workflows/ci.yml`).
- [ ] Automated CD workflow (`.github/workflows/cd.yml`).
- [ ] Protected `main` branch ruleset.

### 📋 Phase 3: 2GP Packaging & Distribution
- [ ] Second-Generation (2GP) Unlocked Package created: `ShopifySalesforceConnector`.
- [ ] Package version built and validated against code coverage requirements.
- [ ] Promoted to **`Released`** status.
- [ ] Direct 1-Click Install URLs generated for Production and Sandbox.

### 📋 Phase 4: Branding & AppExchange Readiness
- [ ] 7 Visual Assets: App Icon (120x120), Hero Banner (16:9), and 4 UI walkthrough screenshots.
- [ ] Production-grade `README.md` with webhook setup and Trailblazer guide.
- [ ] Complete `APPEXCHANGE_LISTING.md` submission dossier.
