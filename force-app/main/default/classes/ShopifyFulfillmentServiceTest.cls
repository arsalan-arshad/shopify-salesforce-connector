/**
 * @description Unit tests for ShopifyFulfillmentService.
 */
@IsTest
private class ShopifyFulfillmentServiceTest {

    @TestSetup
    static void setupTestData() {
        Shopify_Setting__c settings = new Shopify_Setting__c(
            Shop_Domain__c = 'fulfillment-test.myshopify.com',
            Admin_Access_Token__c = 'shpat_mock_token_123',
            Enable_Bidirectional_Fulfillment__c = true
        );
        insert settings;

        Account acct = new Account(Name = 'Fulfillment Test Account');
        insert acct;

        Id stdPbId = Test.getStandardPricebookId();
        Order ord = new Order(
            AccountId = acct.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = stdPbId,
            Shopify_Order_Id__c = 'shp_ord_88219'
        );
        insert ord;
    }

    @IsTest
    static void testPushFulfillmentSuccess() {
        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new ShopifyHttpMock(201, '{"fulfillment": {"id": 112233, "status": "success"}}'));

        ShopifyFulfillmentService.FulfillmentRequest req = new ShopifyFulfillmentService.FulfillmentRequest();
        req.orderId = ord.Id;
        req.trackingNumber = '1Z9999999999999999';
        req.carrier = 'UPS';

        Test.startTest();
        List<ShopifyFulfillmentService.FulfillmentResponse> responses = 
            ShopifyFulfillmentService.pushFulfillments(new List<ShopifyFulfillmentService.FulfillmentRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assert(responses[0].isSuccess, 'Fulfillment push should be successful.');

        List<Shopify_Sync_Log__c> logs = [
            SELECT Id, Status__c, Direction__c
            FROM Shopify_Sync_Log__c
            WHERE Direction__c = 'Outbound_To_Shopify'
        ];
        System.assertEquals(1, logs.size());
        System.assertEquals('Success', logs[0].Status__c);
    }

    @IsTest
    static void testPushFulfillmentRateLimit() {
        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new ShopifyHttpMock(429, '{"errors": "Exceeded 2 calls per second for api client."}'));

        Test.startTest();
        ShopifyFulfillmentService.FulfillmentResponse res = 
            ShopifyFulfillmentService.executeOutboundFulfillment(ord.Id, 'TRACK123', 'FedEx');
        Test.stopTest();

        System.assertEquals(false, res.isSuccess);
        System.assert(res.message.contains('rate limit'));
    }

    @IsTest
    static void testDisabledBidirectionalSync() {
        Shopify_Setting__c settings = [SELECT Id, Enable_Bidirectional_Fulfillment__c FROM Shopify_Setting__c LIMIT 1];
        settings.Enable_Bidirectional_Fulfillment__c = false;
        update settings;

        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        ShopifyFulfillmentService.FulfillmentResponse res = 
            ShopifyFulfillmentService.executeOutboundFulfillment(ord.Id, 'TRACK123', 'FedEx');
        Test.stopTest();

        System.assertEquals(false, res.isSuccess);
        System.assert(res.message.contains('disabled'));
    }

    @IsTest
    static void testMissingShopifyOrderId() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        Order ordWithoutShopifyId = new Order(
            AccountId = acct.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert ordWithoutShopifyId;

        Test.startTest();
        ShopifyFulfillmentService.FulfillmentResponse res = 
            ShopifyFulfillmentService.executeOutboundFulfillment(ordWithoutShopifyId.Id, 'TRACK123', 'USPS');
        Test.stopTest();

        System.assertEquals(false, res.isSuccess);
        System.assert(res.message.contains('no linked Shopify_Order_Id__c'));
    }
}
