/**
 * @description Dead-Letter Queue (DLQ) recovery and replay service for Shopify Connector.
 *              Allows reprocessing failed synchronization events individually or in bulk.
 */
public with sharing class ShopifyDLQService {

    public class ReplayResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String logId;
        @AuraEnabled public String message;

        public ReplayResult(Boolean success, String logId, String message) {
            this.success = success;
            this.logId = logId;
            this.message = message;
        }
    }

    /**
     * @description Replays an individual failed sync log from its stored payload.
     */
    @AuraEnabled
    public static ReplayResult replayFailedLog(Id logId) {
        if (logId == null) {
            return new ReplayResult(false, null, 'Log ID cannot be null.');
        }

        List<Shopify_Sync_Log__c> logs = [
            SELECT Id, Topic__c, Payload__c, Direction__c, Retry_Count__c, Status__c, Shopify_Record_Id__c, Salesforce_Record_Id__c
            FROM Shopify_Sync_Log__c
            WHERE Id = :logId
            LIMIT 1
        ];

        if (logs.isEmpty()) {
            return new ReplayResult(false, logId, 'Sync Log record not found.');
        }

        Shopify_Sync_Log__c log = logs[0];
        if (String.isBlank(log.Payload__c)) {
            return new ReplayResult(false, logId, 'Cannot replay: Stored payload is empty.');
        }

        Integer currentRetries = log.Retry_Count__c != null ? Integer.valueOf(log.Retry_Count__c) : 0;
        log.Retry_Count__c = currentRetries + 1;

        try {
            if (log.Direction__c == 'Outbound_To_Shopify') {
                // Replay outbound fulfillment
                Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(log.Payload__c);
                Map<String, Object> fulfillment = (Map<String, Object>) payloadMap.get('fulfillment');
                Map<String, Object> trackingInfo = (Map<String, Object>) fulfillment.get('tracking_info');
                String trackingNumber = (String) trackingInfo.get('number');
                String carrier = (String) trackingInfo.get('company');

                ShopifyFulfillmentService.FulfillmentResponse res = 
                    ShopifyFulfillmentService.executeOutboundFulfillment(log.Salesforce_Record_Id__c, trackingNumber, carrier);

                if (res.isSuccess) {
                    log.Status__c = 'Replayed';
                    log.Error_Message__c = null;
                    update log;
                    return new ReplayResult(true, logId, 'Outbound fulfillment successfully replayed.');
                } else {
                    log.Error_Message__c = res.message;
                    update log;
                    return new ReplayResult(false, logId, 'Outbound replay failed: ' + res.message);
                }
            } else {
                // Inbound webhook replay
                ShopifySyncEngine.SyncResult result = ShopifySyncEngine.processWebhook(log.Topic__c, log.Payload__c);
                if (result.success) {
                    log.Status__c = 'Replayed';
                    log.Error_Message__c = null;
                    log.Salesforce_Record_Id__c = result.recordId;
                    update log;
                    return new ReplayResult(true, logId, 'Inbound webhook successfully reprocessed.');
                } else {
                    log.Error_Message__c = result.errorMessage;
                    update log;
                    return new ReplayResult(false, logId, 'Replay failed: ' + result.errorMessage);
                }
            }
        } catch (Exception ex) {
            log.Error_Message__c = 'Replay exception: ' + ex.getMessage();
            update log;
            return new ReplayResult(false, logId, log.Error_Message__c);
        }
    }

    /**
     * @description Bulk replays all currently failed sync logs up to a given batch limit.
     */
    @AuraEnabled
    public static Map<String, Object> bulkReplayFailed(Integer limitCount) {
        Integer batchLimit = (limitCount != null && limitCount > 0 && limitCount <= 50) ? limitCount : 25;
        List<Shopify_Sync_Log__c> failedLogs = [
            SELECT Id
            FROM Shopify_Sync_Log__c
            WHERE Status__c = 'Failed'
            ORDER BY CreatedDate ASC
            LIMIT :batchLimit
        ];

        Integer replayedCount = 0;
        Integer failedCount = 0;
        List<String> errors = new List<String>();

        for (Shopify_Sync_Log__c log : failedLogs) {
            ReplayResult res = replayFailedLog(log.Id);
            if (res.success) {
                replayedCount++;
            } else {
                failedCount++;
                errors.add('Log ' + log.Id + ': ' + res.message);
            }
        }

        return new Map<String, Object>{
            'totalProcessed' => failedLogs.size(),
            'replayedCount' => replayedCount,
            'failedCount' => failedCount,
            'errors' => errors
        };
    }

    /**
     * @description Purges historical sync logs older than the specified number of days.
     */
    @AuraEnabled
    public static Integer purgeOldLogs(Integer daysOld) {
        Integer days = (daysOld != null && daysOld > 0) ? daysOld : 30;
        Date cutoffDate = Date.today().addDays(-days);

        List<Shopify_Sync_Log__c> oldLogs = [
            SELECT Id
            FROM Shopify_Sync_Log__c
            WHERE CreatedDate < :cutoffDate
            LIMIT 5000
        ];

        Integer deletedCount = oldLogs.size();
        if (!oldLogs.isEmpty()) {
            delete oldLogs;
        }
        return deletedCount;
    }
}
