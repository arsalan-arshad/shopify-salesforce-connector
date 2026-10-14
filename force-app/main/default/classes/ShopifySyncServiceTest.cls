/**
 * @description Unit tests for ShopifySyncEngine.
 */
@IsTest
private class ShopifySyncServiceTest {

    @TestSetup
    static void setupTestData() {
        Shopify_Setting__c settings = new Shopify_Setting__c(
            Shop_Domain__c = 'my-test-store.myshopify.com',
            Shared_Secret__c = 'test_secret_abc123',
            Admin_Access_Token__c = 'shpat_test_access_token_xyz',
            Abandoned_Cart_Threshold__c = 200.00,
            Auto_Create_Opportunity__c = true,
            Enable_Bidirectional_Fulfillment__c = true,
            Sync_Active__c = true
        );
        insert settings;
    }

    @IsTest
    static void testCustomerCreateAndDeduplication() {
        String payload1 = '{' +
            '"id": 88123,' +
            '"email": "sarah.connor@example.com",' +
            '"phone": "+15551234567",' +
            '"first_name": "Sarah",' +
            '"last_name": "Connor",' +
            '"tags": "VIP, Wholesale",' +
            '"total_spent": "1450.50",' +
            '"orders_count": 8,' +
            '"default_address": {' +
                '"address1": "123 Cyberdyne Way",' +
                '"city": "Los Angeles",' +
                '"province": "California",' +
                '"zip": "90001",' +
                '"country": "United States"' +
            '}' +
        '}';

        Test.startTest();
        ShopifySyncEngine.SyncResult result1 = ShopifySyncEngine.processWebhook('customers/create', payload1);
        Test.stopTest();

        System.assert(result1.success, 'Customer sync should succeed: ' + result1.errorMessage);
        Contact c = [
            SELECT Id, FirstName, LastName, Email, Phone, Shopify_Customer_Id__c, Shopify_Tags__c,
                   Shopify_Total_Spent__c, Shopify_Order_Count__c, MailingStreet, AccountId
            FROM Contact
            WHERE Shopify_Customer_Id__c = '88123'
            LIMIT 1
        ];

        System.assertEquals('Sarah', c.FirstName);
        System.assertEquals('Connor', c.LastName);
        System.assertEquals('sarah.connor@example.com', c.Email);
        System.assertEquals(1450.50, c.Shopify_Total_Spent__c);
        System.assertEquals(8, c.Shopify_Order_Count__c);
        System.assertNotEquals(null, c.AccountId, 'Parent Account should have been created.');

        // Test deduplication on update with higher spend
        String payload2 = '{' +
            '"id": 88123,' +
            '"email": "sarah.connor@example.com",' +
            '"first_name": "Sarah",' +
            '"last_name": "Connor",' +
            '"total_spent": "1890.00",' +
            '"orders_count": 9' +
        '}';

        ShopifySyncEngine.SyncResult result2 = ShopifySyncEngine.processWebhook('customers/update', payload2);
        System.assert(result2.success);

        Integer totalContacts = [SELECT COUNT() FROM Contact WHERE Shopify_Customer_Id__c = '88123'];
        System.assertEquals(1, totalContacts, 'Should not create duplicate contact on update.');
        Contact updatedContact = [SELECT Shopify_Total_Spent__c, Shopify_Order_Count__c FROM Contact WHERE Shopify_Customer_Id__c = '88123'];
        System.assertEquals(1890.00, updatedContact.Shopify_Total_Spent__c);
        System.assertEquals(9, updatedContact.Shopify_Order_Count__c);
    }

    @IsTest
    static void testOrderIngestionAndOpportunitySync() {
        String orderPayload = '{' +
            '"id": 77001,' +
            '"name": "#1042",' +
            '"order_number": 1042,' +
            '"financial_status": "paid",' +
            '"fulfillment_status": "unfulfilled",' +
            '"total_price": "349.99",' +
            '"created_at": "2026-10-14T10:00:00-04:00",' +
            '"customer": {' +
                '"id": 99201,' +
                '"first_name": "John",' +
                '"last_name": "Doe",' +
                '"email": "john.doe@shopifytest.com"' +
            '}' +
        '}';

        Test.startTest();
        ShopifySyncEngine.SyncResult result = ShopifySyncEngine.processWebhook('orders/create', orderPayload);
        Test.stopTest();

        System.assert(result.success, 'Order sync should succeed: ' + result.errorMessage);

        Order ord = [
            SELECT Id, Shopify_Order_Id__c, Shopify_Order_Number__c, Shopify_Financial_Status__c,
                   Shopify_Fulfillment_Status__c, AccountId
            FROM Order
            WHERE Shopify_Order_Id__c = '77001'
            LIMIT 1
        ];

        System.assertEquals('#1042', ord.Shopify_Order_Number__c);
        System.assertEquals('paid', ord.Shopify_Financial_Status__c);
        System.assertEquals('unfulfilled', ord.Shopify_Fulfillment_Status__c);
        System.assertNotEquals(null, ord.AccountId);

        // Verify Opportunity was created
        List<Opportunity> opps = [SELECT Id, Name, Amount, StageName FROM Opportunity WHERE AccountId = :ord.AccountId];
        System.assertEquals(1, opps.size(), 'Associated Opportunity should be created.');
        System.assertEquals(349.99, opps[0].Amount);
    }

    @IsTest
    static void testHighValueAbandonedCheckoutSpawnsLeadAndTask() {
        String checkoutPayload = '{' +
            '"id": "chk_token_9999",' +
            '"token": "chk_token_9999",' +
            '"email": "lead.buyer@example.com",' +
            '"phone": "+15559876543",' +
            '"total_price": "450.00",' +
            '"subtotal_price": "420.00",' +
            '"abandoned_checkout_url": "https://my-test-store.myshopify.com/checkouts/chk_token_9999/recover",' +
            '"customer": {' +
                '"first_name": "Alex",' +
                '"last_name": "Buyer"' +
            '},' +
            '"line_items": [' +
                '{"title": "Enterprise Running Shoes", "quantity": 2, "price": "150.00"},' +
                '{"title": "Wireless Earbuds Pro", "quantity": 1, "price": "120.00"}' +
            ']' +
        '}';

        Test.startTest();
        ShopifySyncEngine.SyncResult result = ShopifySyncEngine.processWebhook('checkouts/create', checkoutPayload);
        Test.stopTest();

        System.assert(result.success, 'Checkout processing should succeed.');

        Lead leadRecord = [
            SELECT Id, FirstName, LastName, Email, Phone, LeadSource, Shopify_Checkout_Id__c,
                   Shopify_Cart_Value__c, Shopify_Cart_Url__c, Shopify_Abandoned_Items__c
            FROM Lead
            WHERE Shopify_Checkout_Id__c = 'chk_token_9999'
            LIMIT 1
        ];

        System.assertEquals('Alex', leadRecord.FirstName);
        System.assertEquals('Buyer', leadRecord.LastName);
        System.assertEquals('Shopify Abandoned Cart', leadRecord.LeadSource);
        System.assertEquals(450.00, leadRecord.Shopify_Cart_Value__c);
        System.assert(leadRecord.Shopify_Abandoned_Items__c.contains('Enterprise Running Shoes'));

        // Verify high-priority Task was spawned
        List<Task> tasks = [SELECT Id, Subject, Priority, Status, WhoId FROM Task WHERE WhoId = :leadRecord.Id];
        System.assertEquals(1, tasks.size(), 'A follow-up Task must be created for the lead owner.');
        System.assertEquals('High', tasks[0].Priority);
    }

    @IsTest
    static void testLowValueAbandonedCheckoutSkipped() {
        String lowValuePayload = '{' +
            '"id": "chk_token_small",' +
            '"email": "small.cart@example.com",' +
            '"total_price": "45.00"' +
        '}';

        Test.startTest();
        ShopifySyncEngine.SyncResult result = ShopifySyncEngine.processWebhook('checkouts/create', lowValuePayload);
        Test.stopTest();

        System.assert(result.success);
        Integer leadCount = [SELECT COUNT() FROM Lead WHERE Shopify_Checkout_Id__c = 'chk_token_small'];
        System.assertEquals(0, leadCount, 'Carts below threshold should not spawn Leads.');
    }

    @IsTest
    static void testDisabledSyncIgnored() {
        Shopify_Setting__c settings = [SELECT Id, Sync_Active__c FROM Shopify_Setting__c LIMIT 1];
        settings.Sync_Active__c = false;
        update settings;

        Test.startTest();
        ShopifySyncEngine.SyncResult result = ShopifySyncEngine.processWebhook('customers/create', '{"id": 111}');
        Test.stopTest();

        System.assert(result.success);
        Shopify_Sync_Log__c log = [
            SELECT Status__c
            FROM Shopify_Sync_Log__c
            WHERE Topic__c = 'customers/create'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Ignored', log.Status__c);
    }

    @IsTest
    static void testInvalidTopicAndEmptyPayload() {
        Test.startTest();
        ShopifySyncEngine.SyncResult res1 = ShopifySyncEngine.processWebhook('unsupported/topic', '{"foo": "bar"}');
        ShopifySyncEngine.SyncResult res2 = ShopifySyncEngine.processWebhook('orders/create', '');
        Test.stopTest();

        System.assert(res1.success);
        System.assert(!res2.success);
    }
}
