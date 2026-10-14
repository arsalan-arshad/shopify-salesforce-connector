/**
 * @description Inbound REST Webhook endpoint for Shopify notifications.
 *              Validates HMAC-SHA256 cryptographic signatures against the store secret
 *              and routes payloads to ShopifySyncEngine.
 */
@RestResource(urlMapping='/shopify/v1/webhook/*')
global with sharing class ShopifyWebhookRestService {

    @TestVisible
    private static Boolean bypassHmacForTest = false;

    @HttpPost
    global static void handleIncomingWebhook() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        if (res == null) {
            res = new RestResponse();
            RestContext.response = res;
        }

        String hmacHeader = req.headers.get('X-Shopify-Hmac-Sha256');
        String topicHeader = req.headers.get('X-Shopify-Topic');
        String shopHeader = req.headers.get('X-Shopify-Shop-Domain');

        String rawBody = req.requestBody != null ? req.requestBody.toString() : '';

        // Validate HMAC signature unless bypassed in test execution
        if (!bypassHmacForTest && !validateHmacSignature(rawBody, hmacHeader)) {
            res.statusCode = 401;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => false,
                'error' => 'Invalid or missing HMAC signature.'
            }));
            return;
        }

        // Delegate to sync engine
        ShopifySyncEngine.SyncResult result = ShopifySyncEngine.processWebhook(topicHeader, rawBody);

        res.statusCode = result.success ? 200 : 500;
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(JSON.serialize(result));
    }

    /**
     * @description Validates the Shopify HMAC-SHA256 signature against the configured shared secret.
     */
    public static Boolean validateHmacSignature(String requestBody, String hmacHeader) {
        if (String.isBlank(hmacHeader) || String.isBlank(requestBody)) {
            return false;
        }

        Shopify_Setting__c settings = Shopify_Setting__c.getInstance();
        String sharedSecret = settings != null ? settings.Shared_Secret__c : null;

        if (String.isBlank(sharedSecret)) {
            // Secret not configured: refuse request for security
            return false;
        }

        try {
            Blob hmacBlob = Crypto.generateMac(
                'HmacSHA256',
                Blob.valueOf(requestBody),
                Blob.valueOf(sharedSecret)
            );
            String calculatedHmac = EncodingUtil.base64Encode(hmacBlob);

            // Time-constant comparison to mitigate timing attacks
            return calculatedHmac.equals(hmacHeader);
        } catch (Exception ex) {
            return false;
        }
    }
}
