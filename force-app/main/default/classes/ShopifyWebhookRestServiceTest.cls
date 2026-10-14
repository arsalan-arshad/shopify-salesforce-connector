/**
 * @description Unit tests for ShopifyWebhookRestService.
 */
@IsTest
private class ShopifyWebhookRestServiceTest {

    @TestSetup
    static void setupSettings() {
        Shopify_Setting__c settings = new Shopify_Setting__c(
            Shop_Domain__c = 'test-store.myshopify.com',
            Shared_Secret__c = 'super_secret_shopify_key_123',
            Admin_Access_Token__c = 'shpat_mock_token_abc',
            Abandoned_Cart_Threshold__c = 150.00,
            Sync_Active__c = true,
            Auto_Create_Opportunity__c = true,
            Enable_Bidirectional_Fulfillment__c = true
        );
        insert settings;
    }

    @IsTest
    static void testValidHmacWebhookHandling() {
        String payload = '{"id": 9901, "email": "valid@example.com", "first_name": "Valid", "last_name": "User"}';
        String secret = 'super_secret_shopify_key_123';
        Blob hmacBlob = Crypto.generateMac('HmacSHA256', Blob.valueOf(payload), Blob.valueOf(secret));
        String validHmac = EncodingUtil.base64Encode(hmacBlob);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/shopify/v1/webhook';
        req.httpMethod = 'POST';
        req.headers.put('X-Shopify-Hmac-Sha256', validHmac);
        req.headers.put('X-Shopify-Topic', 'customers/create');
        req.headers.put('X-Shopify-Shop-Domain', 'test-store.myshopify.com');
        req.requestBody = Blob.valueOf(payload);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ShopifyWebhookRestService.handleIncomingWebhook();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Valid HMAC webhook should return 200.');
        List<Shopify_Sync_Log__c> logs = [SELECT Id, Status__c, Topic__c FROM Shopify_Sync_Log__c WHERE Topic__c = 'customers/create'];
        System.assertEquals(1, logs.size(), 'A sync log should be recorded.');
        System.assertEquals('Success', logs[0].Status__c, 'Log status should be Success.');
    }

    @IsTest
    static void testInvalidHmacRejection() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/shopify/v1/webhook';
        req.httpMethod = 'POST';
        req.headers.put('X-Shopify-Hmac-Sha256', 'bogus_invalid_hmac_signature');
        req.headers.put('X-Shopify-Topic', 'customers/create');
        req.requestBody = Blob.valueOf('{"id": 123}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ShopifyWebhookRestService.handleIncomingWebhook();
        Test.stopTest();

        System.assertEquals(401, res.statusCode, 'Invalid HMAC must return 401 Unauthorized.');
    }

    @IsTest
    static void testBypassHmacForTest() {
        ShopifyWebhookRestService.bypassHmacForTest = true;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/shopify/v1/webhook';
        req.httpMethod = 'POST';
        req.headers.put('X-Shopify-Topic', 'orders/create');
        req.requestBody = Blob.valueOf('{"id": 55501, "order_number": "1001", "total_price": "250.00", "financial_status": "paid"}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ShopifyWebhookRestService.handleIncomingWebhook();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Bypassed test webhook should execute successfully.');
        ShopifyWebhookRestService.bypassHmacForTest = false;
    }

    @IsTest
    static void testMissingSecretValidation() {
        // Clear secret
        Shopify_Setting__c settings = Shopify_Setting__c.getInstance();
        settings.Shared_Secret__c = null;
        update settings;

        Boolean isValid = ShopifyWebhookRestService.validateHmacSignature('{"test": true}', 'any_hmac');
        System.assertEquals(false, isValid, 'Should return false when shared secret is null.');
    }
}
