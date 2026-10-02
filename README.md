# Universal Shopify ↔ Salesforce Connector

> **Open-Source (MIT)** | Built for the E-Commerce & Salesforce Developer Community | Open for PRs & Discussions

## 1. Overview & Vision
A 100% free, high-performance horizontal open-source integration bridge connecting Shopify storefronts with Salesforce CRM.

While existing enterprise tools (MuleSoft, Celigo) cost upwards of $10,000/year and basic middleware (Zapier, Make) charges per task execution, this connector provides a generous, zero-friction sync for core e-commerce data without expensive per-transaction fees.

## 2. Core Features (Horizontal Sync)
- **Customer $\rightarrow$ Contact & Account Sync:**
  - Real-time ingestion on `customers/create` and `customers/update`.
  - Automatic de-duplication by email and phone number.
  - Syncs addresses, customer tags, lifetime spend, and total order count.
- **Order $\rightarrow$ Salesforce Order & Opportunity:**
  - Captures `orders/create` and `orders/paid`.
  - Line items mapped to Salesforce `PricebookEntry` and `OrderItem` / `OpportunityLineItem`.
  - Financial status (Paid, Refunded, Partially Paid) and fulfillment status (Unfulfilled, Fulfilled).
- **Abandoned Checkout $\rightarrow$ High-Priority Lead:**
  - Ingests `checkouts/create` and `checkouts/update`.
  - High-value abandoned carts (e.g. >$200) automatically spawn a Salesforce `Lead` with a follow-up `Task` for sales reps.
- **Bi-directional Inventory / Fulfillment Push:**
  - When warehouse status updates in Salesforce, pushes fulfillment tracking number back to Shopify.

## 3. Architecture & Tech Stack
- **Webhook Gateway:** Lightweight Node.js / Remix / Serverless receiver capturing Shopify HMAC-verified webhooks.
- **Salesforce Connected App:** Uses Salesforce REST API (OAuth 2.0 Client Credentials or JWT Bearer Flow).
- **Packaging:** Salesforce Managed / Unlocked Package containing custom fields, field mapping settings, and sync error log object (`Shopify_Sync_Log__c`).

## 4. AppExchange & Community Strategy
- **Positioning:** "Free Core E-Commerce Sync for Growing Stores".
- **Target Audience:** Any business running both Shopify and Salesforce wanting simple, dependable data flow.

## 5. Open-Source Roadmap & Good First Issues for PRs
- [ ] Add support for Shopify B2B Companies $\rightarrow$ Salesforce Accounts mapping.
- [ ] Multi-currency and multi-tax rate support for international stores.
- [ ] Webhook dead-letter queue (DLQ) retry mechanism with dashboard.
- [ ] Support for custom metadata field-mapping UI in Salesforce Setup.
