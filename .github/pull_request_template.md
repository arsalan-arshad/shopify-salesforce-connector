## Description

<!-- Provide a concise summary of the changes introduced by this pull request. -->

## Webhook & Sync Handlers Affected

- [ ] Customers (`customers/create`, `customers/update`)
- [ ] Orders (`orders/create`, `orders/paid`)
- [ ] Checkouts / Abandoned Carts (`checkouts/create`, `checkouts/update`)
- [ ] Outbound Fulfillments (`ShopifyFulfillmentService`)
- [ ] Dead-Letter Queue (DLQ Replay)
- [ ] Setup LWC (`shopifyConnectorConfig` / `shopifySyncBadge`)

## Type of Change

- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] ⚡ Performance improvement / refactor
- [ ] 📖 Documentation update
- [ ] 🧪 Tests / CI pipeline enhancement

## Checklist

- [ ] All Shopify webhook handlers verify HMAC-SHA256 signatures before processing.
- [ ] All Apex queries enforce `WITH USER_MODE` and classes use `with sharing`.
- [ ] New/modified Apex code includes unit tests with $\ge 85\%$ code coverage.
- [ ] Node gateway test suite passes locally (`npm test`).
- [ ] Prettier and ESLint formatting checks pass (`npm run prettier:check` and `npm run lint`).
- [ ] Dead-Letter Queue (DLQ) logging tested for transient failure recovery.
