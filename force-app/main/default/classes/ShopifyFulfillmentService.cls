/**
 * @description Outbound synchronization service for Shopify fulfillments.
 *              When tracking information is entered or updated in Salesforce,
 *              pushes fulfillment tracking and carrier to the Shopify Admin REST API.
 */
public with sharing class ShopifyFulfillmentService {

    public class FulfillmentRequest {
        @InvocableVariable(label='Salesforce Order ID' required=true)
        public Id orderId;
        @InvocableVariable(label='Tracking Number' required=true)
        public String trackingNumber;
        @InvocableVariable(label='Carrier Name' required=false)
        public String carrier;
    }

    public class FulfillmentResponse {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;
        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(label='Push Fulfillment to Shopify' description='Updates tracking number and carrier on Shopify Order.')
    public static List<FulfillmentResponse> pushFulfillments(List<FulfillmentRequest> requests) {
        List<FulfillmentResponse> responses = new List<FulfillmentResponse>();
        for (FulfillmentRequest req : requests) {
            responses.add(executeOutboundFulfillment(req.orderId, req.trackingNumber, req.carrier));
        }
        return responses;
    }

    public static FulfillmentResponse executeOutboundFulfillment(Id orderId, String trackingNumber, String carrier) {
        Long startTime = System.currentTimeMillis();
        FulfillmentResponse res = new FulfillmentResponse();

        Shopify_Setting__c settings = Shopify_Setting__c.getInstance();
        if (settings == null || String.isBlank(settings.Shop_Domain__c) || String.isBlank(settings.Admin_Access_Token__c)) {
            res.isSuccess = false;
            res.message = 'Shopify credentials not configured in Shopify_Setting__c.';
            return res;
        }

        if (!settings.Enable_Bidirectional_Fulfillment__c) {
            res.isSuccess = false;
            res.message = 'Bidirectional fulfillment sync is disabled in settings.';
            return res;
        }

        List<Order> orders = [
            SELECT Id, Shopify_Order_Id__c, Shopify_Order_Number__c
            FROM Order
            WHERE Id = :orderId
            WITH USER_MODE
            LIMIT 1
        ];

        if (orders.isEmpty() || String.isBlank(orders[0].Shopify_Order_Id__c)) {
            res.isSuccess = false;
            res.message = 'Order has no linked Shopify_Order_Id__c.';
            return res;
        }

        String shopifyOrderId = orders[0].Shopify_Order_Id__c;
        String endpoint = 'https://' + settings.Shop_Domain__c + '/admin/api/2024-01/orders/' + shopifyOrderId + '/fulfillments.json';

        Map<String, Object> payloadMap = new Map<String, Object>{
            'fulfillment' => new Map<String, Object>{
                'notify_customer' => true,
                'tracking_info' => new Map<String, Object>{
                    'number' => trackingNumber,
                    'company' => String.isNotBlank(carrier) ? carrier : 'Other'
                }
            }
        };

        String requestBody = JSON.serialize(payloadMap);

        HttpRequest httpReq = new HttpRequest();
        httpReq.setEndpoint(endpoint);
        httpReq.setMethod('POST');
        httpReq.setHeader('Content-Type', 'application/json');
        httpReq.setHeader('X-Shopify-Access-Token', settings.Admin_Access_Token__c);
        httpReq.setBody(requestBody);
        httpReq.setTimeout(120000);

        Shopify_Sync_Log__c log = new Shopify_Sync_Log__c(
            Topic__c = 'fulfillments/create',
            Shopify_Record_Id__c = shopifyOrderId,
            Salesforce_Record_Id__c = orderId,
            Direction__c = 'Outbound_To_Shopify',
            Payload__c = requestBody,
            Retry_Count__c = 0
        );

        try {
            Http http = new Http();
            HttpResponse httpRes = http.send(httpReq);

            log.Execution_Time_Ms__c = System.currentTimeMillis() - startTime;

            if (httpRes.getStatusCode() == 200 || httpRes.getStatusCode() == 201) {
                log.Status__c = 'Success';
                res.isSuccess = true;
                res.message = 'Successfully pushed fulfillment tracking to Shopify.';
            } else if (httpRes.getStatusCode() == 429) {
                log.Status__c = 'Failed';
                log.Error_Message__c = 'Rate limit encountered (HTTP 429): ' + httpRes.getBody();
                res.isSuccess = false;
                res.message = 'Shopify API rate limit exceeded. Queued for retry.';
            } else {
                log.Status__c = 'Failed';
                log.Error_Message__c = 'HTTP ' + httpRes.getStatusCode() + ': ' + httpRes.getBody();
                res.isSuccess = false;
                res.message = log.Error_Message__c;
            }

            insert as user log;

        } catch (Exception ex) {
            log.Status__c = 'Failed';
            log.Error_Message__c = ex.getMessage() + '\n' + ex.getStackTraceString();
            log.Execution_Time_Ms__c = System.currentTimeMillis() - startTime;
            insert as user log;

            res.isSuccess = false;
            res.message = ex.getMessage();
        }

        return res;
    }
}
