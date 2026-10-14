import jsforce from 'jsforce';

export class SalesforceSyncClient {
  constructor(config = {}) {
    this.loginUrl = config.loginUrl || process.env.SALESFORCE_LOGIN_URL || 'https://login.salesforce.com';
    this.clientId = config.clientId || process.env.SALESFORCE_CLIENT_ID;
    this.clientSecret = config.clientSecret || process.env.SALESFORCE_CLIENT_SECRET;
    this.username = config.username || process.env.SALESFORCE_USERNAME;
    this.password = config.password || process.env.SALESFORCE_PASSWORD;
    this.connection = null;
  }

  async connect() {
    if (this.connection) {
      return this.connection;
    }

    this.connection = new jsforce.Connection({
      loginUrl: this.loginUrl
    });

    if (this.username && this.password) {
      await this.connection.login(this.username, this.password);
    }
    return this.connection;
  }

  /**
   * Forwards inbound webhook to the Apex REST endpoint with automatic retry.
   */
  async forwardWebhookToApex(topic, rawPayload, maxRetries = 3) {
    let attempt = 0;
    while (attempt < maxRetries) {
      attempt++;
      try {
        const conn = await this.connect();
        const response = await conn.apex.post('/shopify/v1/webhook', rawPayload, {
          headers: {
            'Content-Type': 'application/json',
            'X-Shopify-Topic': topic
          }
        });
        return { success: true, attempt, data: response };
      } catch (err) {
        if (attempt >= maxRetries) {
          throw err;
        }
        // Exponential backoff
        const backoffMs = Math.pow(2, attempt) * 500;
        await new Promise((resolve) => setTimeout(resolve, backoffMs));
      }
    }
  }
}
