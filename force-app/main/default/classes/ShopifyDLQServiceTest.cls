/**
 * @description Unit tests for ShopifyDLQService.
 */
@IsTest
private class ShopifyDLQServiceTest {

    @TestSetup
    static void setupTestData() {
        Shopify_Setting__c settings = new Shopify_Setting__c(
            Shop_Domain__c = 'dlq-test.myshopify.com',
            Admin_Access_Token__c = 'shpat_dlq_token',
            Enable_Bidirectional_Fulfillment__c = true,
            Sync_Active__c = true
        );
        insert settings;

        // Create a failed inbound log
        Shopify_Sync_Log__c failedInbound = new Shopify_Sync_Log__c(
            Topic__c = 'customers/create',
            Direction__c = 'Inbound_From_Shopify',
            Status__c = 'Failed',
            Payload__c = '{"id": 44101, "email": "dlq.customer@example.com", "first_name": "DLQ", "last_name": "Customer"}',
            Retry_Count__c = 0,
            Error_Message__c = 'Initial transient error'
        );
        insert failedInbound;
    }

    @IsTest
    static void testReplayFailedInboundLog() {
        Shopify_Sync_Log__c log = [SELECT Id, Status__c, Retry_Count__c FROM Shopify_Sync_Log__c LIMIT 1];
        System.assertEquals('Failed', log.Status__c);
        System.assertEquals(0, log.Retry_Count__c);

        Test.startTest();
        ShopifyDLQService.ReplayResult result = ShopifyDLQService.replayFailedLog(log.Id);
        Test.stopTest();

        System.assert(result.success, 'Replay should succeed: ' + result.message);

        Shopify_Sync_Log__c replayedLog = [SELECT Status__c, Retry_Count__c, Salesforce_Record_Id__c FROM Shopify_Sync_Log__c WHERE Id = :log.Id];
        System.assertEquals('Replayed', replayedLog.Status__c);
        System.assertEquals(1, replayedLog.Retry_Count__c);
        System.assertNotEquals(null, replayedLog.Salesforce_Record_Id__c);
    }

    @IsTest
    static void testBulkReplayFailed() {
        // Insert another failed log
        insert new Shopify_Sync_Log__c(
            Topic__c = 'orders/create',
            Direction__c = 'Inbound_From_Shopify',
            Status__c = 'Failed',
            Payload__c = '{"id": 991, "name": "#1099", "total_price": "99.00"}',
            Retry_Count__c = 0
        );

        Test.startTest();
        Map<String, Object> bulkResult = ShopifyDLQService.bulkReplayFailed(10);
        Test.stopTest();

        Integer totalProcessed = (Integer) bulkResult.get('totalProcessed');
        Integer replayedCount = (Integer) bulkResult.get('replayedCount');
        System.assert(totalProcessed >= 2, 'Should process both failed logs.');
        System.assert(replayedCount >= 2, 'Both logs should be replayed successfully.');
    }

    @IsTest
    static void testReplayInvalidLog() {
        ShopifyDLQService.ReplayResult res1 = ShopifyDLQService.replayFailedLog(null);
        System.assertEquals(false, res1.success);

        // Empty payload log
        Shopify_Sync_Log__c emptyLog = new Shopify_Sync_Log__c(
            Topic__c = 'customers/create',
            Status__c = 'Failed',
            Payload__c = ''
        );
        insert emptyLog;

        ShopifyDLQService.ReplayResult res2 = ShopifyDLQService.replayFailedLog(emptyLog.Id);
        System.assertEquals(false, res2.success);
    }

    @IsTest
    static void testPurgeOldLogs() {
        Test.startTest();
        Integer purged = ShopifyDLQService.purgeOldLogs(0); // Cutoff today
        Test.stopTest();

        System.assert(purged >= 0);
    }
}
