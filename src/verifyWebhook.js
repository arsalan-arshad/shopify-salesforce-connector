import crypto from 'node:crypto';

/**
 * Verifies Shopify HMAC-SHA256 signature using timing-safe comparison.
 * @param {string|Buffer} rawBody - Raw unparsed webhook request body.
 * @param {string} hmacHeader - The X-Shopify-Hmac-Sha256 header.
 * @param {string} secret - Shopify Webhook Shared Secret.
 * @returns {boolean} True if HMAC signature matches.
 */
export function verifyShopifyWebhook(rawBody, hmacHeader, secret) {
  if (!rawBody || !hmacHeader || !secret) {
    return false;
  }

  try {
    const hash = crypto.createHmac('sha256', secret).update(rawBody, 'utf8').digest('base64');

    const expectedBuffer = Buffer.from(hash, 'base64');
    const providedBuffer = Buffer.from(hmacHeader, 'base64');

    if (expectedBuffer.length !== providedBuffer.length) {
      return false;
    }

    return crypto.timingSafeEqual(expectedBuffer, providedBuffer);
  } catch (_err) {
    return false;
  }
}
