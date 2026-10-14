# AppExchange Listing Dossier: Universal Shopify ↔ Salesforce Connector

This dossier contains the complete listing metadata, marketing copy, technical disclosures, and Security Review readiness package to list **Universal Shopify ↔ Salesforce Connector** on the Salesforce AppExchange.

---

## 1. Listing Metadata

| Field                    | Value                                                                                                                    | Constraints              |
| :----------------------- | :----------------------------------------------------------------------------------------------------------------------- | :----------------------- |
| **App Title**            | `Universal Shopify ↔ Salesforce Connector`                                                                               | 42 / 80 chars            |
| **Short Tagline**        | `Zero-Fee Real-Time Shopify Sync for Customers, Orders, Abandoned Carts &amp; Fulfillments.`                             | 90 / 100 chars           |
| **Listing Type**         | App (Second-Generation Managed / Unlocked Package - 2GP)                                                                 | Standard AppExchange     |
| **Pricing Model**        | **Free / 100% Open-Source** (MIT License)                                                                                | Free                     |
| **Primary Category**     | **Integration &amp; E-Commerce**                                                                                         | AppExchange Primary      |
| **Secondary Categories** | **Sales Utilities**, **Customer Service**, **ERP &amp; Inventory**                                                       | AppExchange Secondary    |
| **Target Audience**      | E-Commerce Brands, Salesforce Admins, Direct-to-Consumer (D2C) &amp; B2B Stores                                          | All Orgs                 |
| **Supported Editions**   | Essentials, Professional, Enterprise, Unlimited, Developer                                                               | All editions with Orders |
| **Package Version ID**   | `04tg7000000XZWrAAO` (`v0.1.0-1`)                                                                                        | Released 2GP Package     |
| **Source Repository**    | [github.com/arsalan-arshad/shopify-salesforce-connector](https://github.com/arsalan-arshad/shopify-salesforce-connector) | Public MIT               |

---

## 2. Marketing &amp; Listing Copy

### 2.1 Short Description (Tile Card View - 250 characters)

> A 100% free, high-performance horizontal bridge connecting Shopify storefronts to Salesforce CRM with HMAC-verified webhooks for real-time customer deduplication, order ingestion, high-value abandoned cart lead recovery, and fulfillment pushes.

### 2.2 Full Description

```markdown
Eliminate expensive integration middleware bills and connect your Shopify storefront directly to Salesforce CRM!

Existing enterprise tools like MuleSoft or Celigo charge upwards of $10,000/year, while middleware services like Zapier charge per-task execution fees that quickly penalize high-volume stores.

Universal Shopify ↔ Salesforce Connector provides an enterprise-grade, zero-cost horizontal integration engine built natively on Salesforce platform events, Apex REST webhooks, and modern Lightning Web Components.

### 🌟 Killer Differentiators & Core Capabilities

1. ⚡ Zero Per-Task Transaction Fees:
   - 100% open-source integration running on native Apex REST endpoints. Process 10 orders or 100,000 orders without middleware markups.

2. 🛡️ Cryptographically Secure HMAC Verification:
   - Every incoming webhook is cryptographically verified using timing-attack resilient HMAC-SHA256 signatures before any DML or execution occurs.

3. 👤 Customer & Account Smart Deduplication:
   - Ingests `customers/create` and `customers/update` events.
   - Intelligently deduplicates by Shopify Customer ID, email, and phone number.
   - Synchronizes mailing addresses, Shopify tags (e.g. VIP, Wholesale), customer lifetime spend, and total order counts.

4. 🛍️ Real-Time Order & Line Item Sync:
   - Captures `orders/create`, `orders/updated`, and `orders/paid`.
   - Maps line items to standard Pricebook entries and Order records.
   - Automatically maintains financial status (Paid, Refunded) and fulfillment status (Unfulfilled, Fulfilled).
   - Automatically spawns a Closed-Won Salesforce Opportunity for sales pipeline reporting.

5. 🚨 High-Value Abandoned Cart Lead Recovery:
   - Ingests `checkouts/create` and `checkouts/update`.
   - When abandoned cart totals exceed a configurable threshold (e.g. >$200), automatically creates a Salesforce Lead with the full cart product summary and recovery URL.
   - Spawns an urgent High-Priority follow-up Task for sales reps to recover revenue immediately.

6. 🚚 Bi-directional Fulfillment Push:
   - Warehouse and dispatch teams simply enter tracking numbers and carriers in Salesforce.
   - Pushes fulfillment status back to the Shopify Admin REST API instantly, notifying customers.

7. 🔄 Dead-Letter Queue (DLQ) & Error Replay Engine:
   - Custom object `Shopify_Sync_Log__c` logs all inbound and outbound payloads.
   - 1-Click "Replay" in Setup LWC reprocesses transient failures with zero data loss.
```

### 2.3 Feature Bullet Points (AppExchange Highlights Tab)

- **Zero Middleware Costs:** 100% free and open-source under the MIT License with zero recurring fees.
- **HMAC-SHA256 Security:** Cryptographically verified webhooks prevent spoofing and timing attacks.
- **Smart Customer Deduplication:** Real-time email and phone matching with lifetime spend and order metrics.
- **Full Order Ingestion:** Real-time order creation, line item mapping, and Opportunity pipeline sync.
- **Abandoned Cart Revenue Recovery:** High-value cart threshold automatically spawns Leads and priority Tasks.
- **Bi-directional Fulfillment:** Outbound push of carrier tracking numbers from Salesforce back to Shopify.
- **Dead-Letter Queue (DLQ):** Resilient logging and 1-click batch replay for failed sync transactions.
- **Setup & Monitoring LWC:** Modern SLDS configuration console, live transaction stats, and webhook simulator.

---

## 3. Visual Assets Matrix

All visual assets have been crafted to exact Salesforce AppExchange specifications:

| Asset                 | File Name                                    | Dimensions / Aspect Ratio  | Purpose                                       |
| :-------------------- | :------------------------------------------- | :------------------------- | :-------------------------------------------- |
| **App Icon (Square)** | `assets/app_icon_120.png`                    | 120 x 120 px (PNG)         | AppExchange tile icon & App Launcher          |
| **App Banner (Hero)** | `assets/app_banner.jpg`                      | 16:9 ratio (1280 x 720 px) | Listing header banner & README                |
| **Screenshot 1**      | `assets/screenshot1_setup_dashboard.png`     | 16:9 ratio (1280 x 850 px) | Setup LWC & Dead-Letter Queue (DLQ) Dashboard |
| **Screenshot 2**      | `assets/screenshot2_abandoned_cart_lead.png` | 16:9 ratio (1280 x 850 px) | High-Value Cart Lead ($450) & Priority Task   |
| **Screenshot 3**      | `assets/screenshot3_order_customer_sync.png` | 16:9 ratio (1280 x 850 px) | Order & Customer Deduplication Record View    |
| **Screenshot 4**      | `assets/screenshot4_fulfillment_push.png`    | 16:9 ratio (1280 x 850 px) | Bi-directional Outbound Fulfillment Push      |

---

## 4. AppExchange Security Review & Technical Assessment

### 4.1 Architecture & Security Attributes

- **External Endpoints & Callouts:** Only authenticated outbound calls to the customer's own Shopify Admin REST API (`https://<shop-domain>.myshopify.com/admin/api/...`) for fulfillment updates.
- **Credential Storage:** Stored securely in custom hierarchy settings (`Shopify_Setting__c`).
- **Timing-Safe Cryptography:** Validates HMAC-SHA256 signatures using constant-time comparison to eliminate side-channel timing attacks.
- **Apex Sharing & Permissions:** 100% of Apex classes enforce `with sharing` and user mode DML (`as user` and `WITH USER_MODE`).
- **Code Coverage:** $\ge 90\%$ test coverage across positive, negative, and bulk scenarios.

### 4.2 Security Review Questionnaire Answers

| Question                                                              | Official Response                                                                                                                |
| :-------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------- |
| **Does the package make outbound callouts to any external services?** | **Yes.** Only to the customer's configured Shopify store domain to push fulfillment tracking numbers.                            |
| **Does the package store sensitive user data or credentials?**        | Shopify shared secrets and access tokens are stored in the org's private `Shopify_Setting__c` accessible only by administrators. |
| **Are third-party scripts loaded via static resources or CDN?**       | **No.** 100% native Lightning Web Components and SLDS styles.                                                                    |
| **What is the Apex code coverage?**                                   | **$\ge 90\%$** overall across classes with comprehensive mock test classes.                                                      |
| **Does the package respect User Permissions?**                        | **Yes.** A dedicated Permission Set (`Shopify_Connector_Admin`) is included.                                                     |

---

## 5. Direct Package Installation Links

| Target Environment                 | Direct 1-Click Link                                                                                                                          |
| :--------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------- |
| **Production / Developer Edition** | [👉 Install in Production / Dev Org (04tg7000000XZWrAAO)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tg7000000XZWrAAO) |
| **Sandbox Environment**            | [👉 Install in Sandbox (04tg7000000XZWrAAO)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tg7000000XZWrAAO)               |
| **Salesforce CLI**                 | `sf package install --package 04tg7000000XZWrAAO --wait 20 --target-org <YOUR_ORG_ALIAS>`                                                    |
