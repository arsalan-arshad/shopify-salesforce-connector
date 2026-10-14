import express from 'express';
import dotenv from 'dotenv';
import { fileURLToPath } from 'node:url';
import { verifyShopifyWebhook } from './verifyWebhook.js';
import { SalesforceSyncClient } from './salesforceClient.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;
const SHOPIFY_SECRET = process.env.SHOPIFY_WEBHOOK_SECRET || 'test_shopify_secret';

const sfClient = new SalesforceSyncClient();

// Capture raw body for accurate cryptographic HMAC verification
app.use(
  express.json({
    verify: (req, _res, buf) => {
      req.rawBody = buf.toString('utf8');
    }
  })
);

// Health check endpoint
app.get('/health', (_req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '0.1.0'
  });
});

// Shopify Webhook Ingestion Endpoint
app.post('/webhook', async (req, res) => {
  const hmacHeader = req.get('X-Shopify-Hmac-Sha256');
  const topic = req.get('X-Shopify-Topic');
  const shopDomain = req.get('X-Shopify-Shop-Domain');

  // Verify HMAC signature
  const isValid = verifyShopifyWebhook(req.rawBody, hmacHeader, SHOPIFY_SECRET);
  if (!isValid) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Invalid HMAC-SHA256 signature.'
    });
  }

  try {
    const result = {
      status: 'accepted',
      topic,
      shopDomain,
      receivedAt: new Date().toISOString()
    };

    if (process.env.SALESFORCE_USERNAME) {
      await sfClient.forwardWebhookToApex(topic, req.body);
    }

    return res.status(200).json(result);
  } catch (err) {
    console.error('Webhook ingestion error:', err);
    return res.status(500).json({
      error: 'Processing Error',
      message: err.message
    });
  }
});

// Only listen when executed directly from CLI
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  app.listen(PORT, () => {
    console.log(`⚡ Shopify ↔ Salesforce Connector gateway running on port ${PORT}`);
  });
}

export default app;
