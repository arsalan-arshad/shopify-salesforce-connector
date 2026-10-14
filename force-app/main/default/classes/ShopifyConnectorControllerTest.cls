/**
 * @description Unit tests for ShopifyConnectorController.
 */
@IsTest
private class ShopifyConnectorControllerTest {

    @TestSetup
    static void setupTestData() {
        Shopify_Setting__c settings = new Shopify_Setting__c(
            Shop_Domain__c = 'controller-store.myshopify.com',
            Shared_Secret__c = 'controller_secret_123',
            Admin_Access_Token__c = 'shpat_controller_tok',
            Abandoned_Cart_Threshold__c = 250.00,
            Auto_Create_Opportunity__c = true,
            Enable_Bidirectional_Fulfillment__c = true,
            Sync_Active__c = true
        );
        insert settings;

        Shopify_Sync_Log__c log1 = new Shopify_Sync_Log__c(
            Topic__c = 'customers/create',
            Status__c = 'Success',
            Direction__c = 'Inbound_From_Shopify'
        );
        Shopify_Sync_Log__c log2 = new Shopify_Sync_Log__c(
            Topic__c = 'orders/create',
            Status__c = 'Failed',
            Direction__c = 'Inbound_From_Shopify',
            Payload__c = '{"id": 99912, "name": "#1099"}'
        );
        insert new List<Shopify_Sync_Log__c>{ log1, log2 };
    }

    @IsTest
    static void testGetConnectorSettings() {
        Test.startTest();
        Map<String, Object> settingsMap = ShopifyConnectorController.getConnectorSettings();
        Test.stopTest();

        System.assertEquals('controller-store.myshopify.com', settingsMap.get('shopDomain'));
        System.assertEquals(true, settingsMap.get('hasSharedSecret'));
        System.assertEquals(true, settingsMap.get('hasAdminToken'));
        System.assertEquals(250.00, settingsMap.get('abandonedCartThreshold'));
        System.assert(((String) settingsMap.get('webhookEndpoint')).contains('/services/apexrest/shopify/v1/webhook'));
    }

    @IsTest
    static void testSaveConnectorSettings() {
        Map<String, Object> newConfig = new Map<String, Object>{
            'shopDomain' => 'updated-store.myshopify.com',
            'sharedSecret' => 'new_secret_key',
            'adminAccessToken' => 'new_token_val',
            'abandonedCartThreshold' => 300.00,
            'enableBidirectionalFulfillment' => false,
            'autoCreateOpportunity' => false,
            'syncActive' => false
        };

        Test.startTest();
        Boolean success = ShopifyConnectorController.saveConnectorSettings(newConfig);
        Test.stopTest();

        System.assertEquals(true, success);
        Shopify_Setting__c updated = Shopify_Setting__c.getInstance();
        System.assertEquals('updated-store.myshopify.com', updated.Shop_Domain__c);
        System.assertEquals(300.00, updated.Abandoned_Cart_Threshold__c);
        System.assertEquals(false, updated.Sync_Active__c);
    }

    @IsTest
    static void testGetSyncStats() {
        Test.startTest();
        Map<String, Object> stats = ShopifyConnectorController.getSyncStats();
        Test.stopTest();

        System.assertEquals(2, stats.get('total24h'));
        System.assertEquals(1, stats.get('success24h'));
        System.assertEquals(1, stats.get('failed24h'));
        System.assertEquals(1, stats.get('totalPendingDlq'));
        System.assertEquals(50.0, stats.get('successRate'));
    }

    @IsTest
    static void testGetRecentLogs() {
        Test.startTest();
        List<Shopify_Sync_Log__c> allLogs = ShopifyConnectorController.getRecentLogs(10, 'All');
        List<Shopify_Sync_Log__c> failedLogs = ShopifyConnectorController.getRecentLogs(10, 'Failed');
        Test.stopTest();

        System.assertEquals(2, allLogs.size());
        System.assertEquals(1, failedLogs.size());
        System.assertEquals('Failed', failedLogs[0].Status__c);
    }

    @IsTest
    static void testReplayAndSimulate() {
        Shopify_Sync_Log__c failedLog = [SELECT Id FROM Shopify_Sync_Log__c WHERE Status__c = 'Failed' LIMIT 1];

        Test.startTest();
        ShopifyDLQService.ReplayResult replayRes = ShopifyConnectorController.replayLog(failedLog.Id);
        Map<String, Object> bulkRes = ShopifyConnectorController.bulkReplayFailed();
        ShopifySyncEngine.SyncResult simRes = ShopifyConnectorController.simulateWebhook(
            'customers/create',
            '{"id": 12345, "email": "sim@example.com", "first_name": "Sim", "last_name": "Test"}'
        );
        Test.stopTest();

        System.assert(replayRes.success != null);
        System.assert(bulkRes.containsKey('totalProcessed'));
        System.assertEquals(true, simRes.success);
    }
}
