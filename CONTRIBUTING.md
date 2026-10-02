# Contributing to Universal Shopify ↔ Salesforce Connector

Thank you for helping build an open-source, zero-cost alternative to expensive integration middleware!

## Local Development Workflow
1. Clone the repository and install dependencies:
   ```bash
   npm install
   ```
2. Copy environment template:
   ```bash
   cp .env.example .env
   ```
3. Run the development server:
   ```bash
   npm run dev
   ```

## PR Requirements
- All Shopify webhook handlers must verify HMAC signatures.
- API calls to Salesforce must use exponential backoff and rate-limit safety checks.
- Adhere to clean asynchronous error handling and logging.
