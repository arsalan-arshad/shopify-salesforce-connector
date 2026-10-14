import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { verifyShopifyWebhook } from '../src/verifyWebhook.js';
import app from '../src/server.js';

test('HMAC Verification Unit Tests', async (t) => {
  const secret = 'test_shopify_secret_key_99';
  const payload = JSON.stringify({ id: 1001, email: 'customer@example.com' });

  await t.test('calculates and verifies valid HMAC-SHA256 signature', () => {
    const validHmac = crypto.createHmac('sha256', secret).update(payload, 'utf8').digest('base64');

    const isValid = verifyShopifyWebhook(payload, validHmac, secret);
    assert.equal(isValid, true, 'HMAC should match for identical payload and secret');
  });

  await t.test('rejects tampered payload', () => {
    const validHmac = crypto.createHmac('sha256', secret).update(payload, 'utf8').digest('base64');

    const tamperedPayload = JSON.stringify({ id: 1001, email: 'hacker@example.com' });
    const isValid = verifyShopifyWebhook(tamperedPayload, validHmac, secret);
    assert.equal(isValid, false, 'Tampered payload must fail HMAC verification');
  });

  await t.test('rejects invalid signature or wrong secret', () => {
    const wrongSecret = 'another_secret_key';
    const invalidHmac = crypto.createHmac('sha256', wrongSecret).update(payload, 'utf8').digest('base64');

    const isValid = verifyShopifyWebhook(payload, invalidHmac, secret);
    assert.equal(isValid, false, 'Wrong secret must fail verification');
  });

  await t.test('handles missing or empty arguments safely', () => {
    assert.equal(verifyShopifyWebhook(null, 'hmac', secret), false);
    assert.equal(verifyShopifyWebhook(payload, null, secret), false);
    assert.equal(verifyShopifyWebhook(payload, 'hmac', null), false);
  });
});

test('Express Gateway HTTP Tests', async (t) => {
  await t.test('GET /health returns 200 and healthy status', async () => {
    const server = app.listen(0);
    const port = server.address().port;

    try {
      const res = await fetch(`http://localhost:${port}/health`);
      assert.equal(res.status, 200);
      const json = await res.json();
      assert.equal(json.status, 'healthy');
      assert.equal(json.version, '0.1.0');
    } finally {
      server.close();
    }
  });

  await t.test('POST /webhook without HMAC returns 401 Unauthorized', async () => {
    const server = app.listen(0);
    const port = server.address().port;

    try {
      const res = await fetch(`http://localhost:${port}/webhook`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ test: true })
      });
      assert.equal(res.status, 401);
      const json = await res.json();
      assert.equal(json.error, 'Unauthorized');
    } finally {
      server.close();
    }
  });

  await t.test('POST /webhook with valid HMAC returns 200 OK', async () => {
    const server = app.listen(0);
    const port = server.address().port;
    const secret = process.env.SHOPIFY_WEBHOOK_SECRET || 'test_shopify_secret';
    const payload = JSON.stringify({ id: 991, order_number: '1099' });

    const validHmac = crypto.createHmac('sha256', secret).update(payload, 'utf8').digest('base64');

    try {
      const res = await fetch(`http://localhost:${port}/webhook`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Shopify-Hmac-Sha256': validHmac,
          'X-Shopify-Topic': 'orders/create',
          'X-Shopify-Shop-Domain': 'test-shop.myshopify.com'
        },
        body: payload
      });
      assert.equal(res.status, 200);
      const json = await res.json();
      assert.equal(json.status, 'accepted');
      assert.equal(json.topic, 'orders/create');
    } finally {
      server.close();
    }
  });
});
