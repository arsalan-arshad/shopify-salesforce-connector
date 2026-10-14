/**
 * @description Controller for the Shopify Connector Setup and DLQ Monitoring LWC.
 *              Provides administration, live analytics, settings management, and replay controls.
 */
public with sharing class ShopifyConnectorController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getConnectorSettings() {
        Shopify_Setting__c settings = Shopify_Setting__c.getInstance();
        String myDomainUrl = URL.getOrgDomainUrl().toExternalForm();
        String webhookEndpoint = myDomainUrl + '/services/apexrest/shopify/v1/webhook';

        Map<String, Object> res = new Map<String, Object>{
            'shopDomain' => settings != null ? settings.Shop_Domain__c : '',
            'hasSharedSecret' => (settings != null && String.isNotBlank(settings.Shared_Secret__c)),
            'hasAdminToken' => (settings != null && String.isNotBlank(settings.Admin_Access_Token__c)),
            'abandonedCartThreshold' => (settings != null && settings.Abandoned_Cart_Threshold__c != null) 
                ? settings.Abandoned_Cart_Threshold__c : 200.00,
            'enableBidirectionalFulfillment' => (settings != null ? settings.Enable_Bidirectional_Fulfillment__c : true),
            'autoCreateOpportunity' => (settings != null ? settings.Auto_Create_Opportunity__c : true),
            'syncActive' => (settings != null ? settings.Sync_Active__c : true),
            'webhookEndpoint' => webhookEndpoint
        };

        return res;
    }

    @AuraEnabled
    public static Boolean saveConnectorSettings(Map<String, Object> config) {
        Shopify_Setting__c settings = Shopify_Setting__c.getInstance();
        if (settings == null) {
            settings = new Shopify_Setting__c();
        }

        if (config.containsKey('shopDomain')) {
            settings.Shop_Domain__c = (String) config.get('shopDomain');
        }
        if (config.containsKey('sharedSecret') && String.isNotBlank((String) config.get('sharedSecret'))) {
            settings.Shared_Secret__c = (String) config.get('sharedSecret');
        }
        if (config.containsKey('adminAccessToken') && String.isNotBlank((String) config.get('adminAccessToken'))) {
            settings.Admin_Access_Token__c = (String) config.get('adminAccessToken');
        }
        if (config.containsKey('abandonedCartThreshold')) {
            settings.Abandoned_Cart_Threshold__c = Decimal.valueOf(String.valueOf(config.get('abandonedCartThreshold')));
        }
        if (config.containsKey('enableBidirectionalFulfillment')) {
            settings.Enable_Bidirectional_Fulfillment__c = (Boolean) config.get('enableBidirectionalFulfillment');
        }
        if (config.containsKey('autoCreateOpportunity')) {
            settings.Auto_Create_Opportunity__c = (Boolean) config.get('autoCreateOpportunity');
        }
        if (config.containsKey('syncActive')) {
            settings.Sync_Active__c = (Boolean) config.get('syncActive');
        }

        upsert settings;
        return true;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getSyncStats() {
        DateTime last24Hours = DateTime.now().addHours(-24);

        Integer total24h = [
            SELECT COUNT()
            FROM Shopify_Sync_Log__c
            WHERE CreatedDate >= :last24Hours
        ];

        Integer success24h = [
            SELECT COUNT()
            FROM Shopify_Sync_Log__c
            WHERE CreatedDate >= :last24Hours AND Status__c IN ('Success', 'Replayed')
        ];

        Integer failed24h = [
            SELECT COUNT()
            FROM Shopify_Sync_Log__c
            WHERE CreatedDate >= :last24Hours AND Status__c = 'Failed'
        ];

        Integer totalPending = [
            SELECT COUNT()
            FROM Shopify_Sync_Log__c
            WHERE Status__c = 'Failed'
        ];

        Decimal successRate = total24h > 0 ? ((Decimal) success24h / (Decimal) total24h) * 100.0 : 100.0;

        return new Map<String, Object>{
            'total24h' => total24h,
            'success24h' => success24h,
            'failed24h' => failed24h,
            'totalPendingDlq' => totalPending,
            'successRate' => successRate.setScale(1)
        };
    }

    @AuraEnabled
    public static List<Shopify_Sync_Log__c> getRecentLogs(Integer limitCount, String statusFilter) {
        Integer queryLimit = (limitCount != null && limitCount > 0 && limitCount <= 100) ? limitCount : 50;

        if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
            return [
                SELECT Id, Name, Topic__c, Status__c, Shopify_Record_Id__c, Salesforce_Record_Id__c,
                       Direction__c, Execution_Time_Ms__c, Retry_Count__c, Error_Message__c, CreatedDate
                FROM Shopify_Sync_Log__c
                WHERE Status__c = :statusFilter
                ORDER BY CreatedDate DESC
                LIMIT :queryLimit
            ];
        }

        return [
            SELECT Id, Name, Topic__c, Status__c, Shopify_Record_Id__c, Salesforce_Record_Id__c,
                   Direction__c, Execution_Time_Ms__c, Retry_Count__c, Error_Message__c, CreatedDate
            FROM Shopify_Sync_Log__c
            ORDER BY CreatedDate DESC
            LIMIT :queryLimit
        ];
    }

    @AuraEnabled
    public static ShopifyDLQService.ReplayResult replayLog(Id logId) {
        return ShopifyDLQService.replayFailedLog(logId);
    }

    @AuraEnabled
    public static Map<String, Object> bulkReplayFailed() {
        return ShopifyDLQService.bulkReplayFailed(25);
    }

    @AuraEnabled
    public static ShopifySyncEngine.SyncResult simulateWebhook(String topic, String payload) {
        return ShopifySyncEngine.processWebhook(topic, payload);
    }
}
