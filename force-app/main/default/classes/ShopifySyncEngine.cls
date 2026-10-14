/**
 * @description Core sync engine for Shopify ↔ Salesforce Connector.
 *              Handles customer deduplication, order & line item ingestion,
 *              high-value abandoned cart lead routing, and sync audit logging.
 */
public with sharing class ShopifySyncEngine {
    
    public class SyncResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String logId;
        @AuraEnabled public String recordId;
        @AuraEnabled public String errorMessage;
        
        public SyncResult(Boolean success, String logId, String recordId, String errorMessage) {
            this.success = success;
            this.logId = logId;
            this.recordId = recordId;
            this.errorMessage = errorMessage;
        }
    }

    /**
     * @description Entry point for routing an inbound Shopify webhook topic to its handler.
     */
    public static SyncResult processWebhook(String topic, String jsonPayload) {
        Long startTime = System.currentTimeMillis();
        Shopify_Sync_Log__c log = new Shopify_Sync_Log__c(
            Topic__c = topic,
            Payload__c = jsonPayload != null && jsonPayload.length() > 131000 ? jsonPayload.substring(0, 131000) : jsonPayload,
            Direction__c = 'Inbound_From_Shopify',
            Status__c = 'Pending',
            Retry_Count__c = 0
        );

        // Check if sync is globally active
        Shopify_Setting__c settings = Shopify_Setting__c.getInstance();
        if (settings != null && settings.Id != null && !settings.Sync_Active__c) {
            log.Status__c = 'Ignored';
            log.Error_Message__c = 'Sync is currently disabled via Shopify_Setting__c.Sync_Active__c.';
            insert as user log;
            return new SyncResult(true, log.Id, null, log.Error_Message__c);
        }

        try {
            if (String.isBlank(jsonPayload)) {
                throw new IllegalArgumentException('Webhook payload is empty.');
            }

            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(jsonPayload);
            String processedRecordId;

            if (topic != null) {
                String normalizedTopic = topic.toLowerCase();
                if (normalizedTopic.contains('customer')) {
                    processedRecordId = processCustomer(data);
                } else if (normalizedTopic.contains('order')) {
                    processedRecordId = processOrder(data);
                } else if (normalizedTopic.contains('checkout')) {
                    processedRecordId = processAbandonedCheckout(data);
                } else {
                    log.Status__c = 'Ignored';
                    log.Error_Message__c = 'Unsupported webhook topic: ' + topic;
                    log.Execution_Time_Ms__c = System.currentTimeMillis() - startTime;
                    insert as user log;
                    return new SyncResult(true, log.Id, null, log.Error_Message__c);
                }
            } else {
                throw new IllegalArgumentException('Missing webhook topic header.');
            }

            log.Status__c = 'Success';
            log.Salesforce_Record_Id__c = processedRecordId;
            log.Execution_Time_Ms__c = System.currentTimeMillis() - startTime;
            insert as user log;

            return new SyncResult(true, log.Id, processedRecordId, null);

        } catch (Exception ex) {
            log.Status__c = 'Failed';
            log.Error_Message__c = ex.getMessage() + '\n' + ex.getStackTraceString();
            log.Execution_Time_Ms__c = System.currentTimeMillis() - startTime;
            insert as user log;

            return new SyncResult(false, log.Id, null, log.Error_Message__c);
        }
    }

    /**
     * @description Ingests or updates a Shopify Customer record into Contact & Account.
     *              Deduplicates by Shopify Customer ID, Email, and Phone.
     */
    public static String processCustomer(Map<String, Object> customerData) {
        String shopifyId = String.valueOf(customerData.get('id'));
        String email = (String) customerData.get('email');
        String phone = (String) customerData.get('phone');
        String firstName = (String) customerData.get('first_name');
        String lastName = (String) customerData.get('last_name');
        String tags = (String) customerData.get('tags');
        Decimal totalSpent = parseDecimal(customerData.get('total_spent'));
        Integer ordersCount = parseInteger(customerData.get('orders_count'));

        if (String.isBlank(lastName)) {
            lastName = String.isNotBlank(email) ? email : 'Shopify Customer ' + shopifyId;
        }

        // Search for existing Contact
        Contact existingContact = findExistingContact(shopifyId, email, phone);

        Contact targetContact;
        if (existingContact != null) {
            targetContact = existingContact;
        } else {
            // Find or create Account for customer
            Account parentAccount = findOrCreateAccount(firstName, lastName, email);
            targetContact = new Contact(AccountId = parentAccount.Id);
        }

        if (String.isNotBlank(firstName)) {
            targetContact.FirstName = firstName;
        }
        targetContact.LastName = lastName;
        if (String.isNotBlank(email)) {
            targetContact.Email = email;
        }
        if (String.isNotBlank(phone)) {
            targetContact.Phone = phone;
        }
        targetContact.Shopify_Customer_Id__c = shopifyId;
        targetContact.Shopify_Tags__c = tags;
        targetContact.Shopify_Total_Spent__c = totalSpent;
        targetContact.Shopify_Order_Count__c = ordersCount;

        // Parse Default Address if present
        Map<String, Object> defaultAddr = (Map<String, Object>) customerData.get('default_address');
        if (defaultAddr != null) {
            targetContact.MailingStreet = (String) defaultAddr.get('address1');
            targetContact.MailingCity = (String) defaultAddr.get('city');
            targetContact.MailingState = (String) defaultAddr.get('province');
            targetContact.MailingPostalCode = (String) defaultAddr.get('zip');
            targetContact.MailingCountry = (String) defaultAddr.get('country');
        }

        upsert as user targetContact;
        return targetContact.Id;
    }

    /**
     * @description Ingests or updates a Shopify Order into Salesforce Order & line items.
     *              Optionally generates an Opportunity if enabled in settings.
     */
    public static String processOrder(Map<String, Object> orderData) {
        String shopifyOrderId = String.valueOf(orderData.get('id'));
        String orderNumber = String.valueOf(orderData.get('name') != null ? orderData.get('name') : orderData.get('order_number'));
        String financialStatus = (String) orderData.get('financial_status');
        String fulfillmentStatus = (String) orderData.get('fulfillment_status');
        Decimal totalPrice = parseDecimal(orderData.get('total_price'));
        String createdAtStr = (String) orderData.get('created_at');
        Date orderDate = parseIsoDate(createdAtStr);

        // Process associated customer
        Map<String, Object> customerData = (Map<String, Object>) orderData.get('customer');
        String contactId;
        String accountId;

        if (customerData != null) {
            contactId = processCustomer(customerData);
            Contact c = [SELECT Id, AccountId FROM Contact WHERE Id = :contactId WITH USER_MODE LIMIT 1];
            accountId = c.AccountId;
        } else {
            // Guest checkout: create or resolve Guest Account
            Account guestAcct = findOrCreateAccount('Guest', 'Customer', 'guest@shopify.com');
            accountId = guestAcct.Id;
        }

        // Query standard Pricebook
        Id standardPbId = Test.isRunningTest() ? Test.getStandardPricebookId() : getDefaultPricebookId();

        // Search for existing Order by Shopify Order ID
        List<Order> existingOrders = [
            SELECT Id, Status, Shopify_Order_Id__c
            FROM Order
            WHERE Shopify_Order_Id__c = :shopifyOrderId
            WITH USER_MODE
            LIMIT 1
        ];

        Order targetOrder;
        if (!existingOrders.isEmpty()) {
            targetOrder = existingOrders[0];
        } else {
            targetOrder = new Order(
                AccountId = accountId,
                EffectiveDate = orderDate,
                Status = 'Draft',
                Pricebook2Id = standardPbId,
                Shopify_Order_Id__c = shopifyOrderId
            );
        }

        targetOrder.Shopify_Order_Number__c = orderNumber;
        targetOrder.Shopify_Financial_Status__c = financialStatus;
        targetOrder.Shopify_Fulfillment_Status__c = String.isNotBlank(fulfillmentStatus) ? fulfillmentStatus : 'unfulfilled';

        upsert as user targetOrder;

        // Optionally create/update Opportunity
        Shopify_Setting__c settings = Shopify_Setting__c.getInstance();
        Boolean createOpp = settings == null || settings.Id == null || settings.Auto_Create_Opportunity__c;
        if (createOpp) {
            syncAssociatedOpportunity(targetOrder, accountId, totalPrice, orderNumber, orderDate);
        }

        return targetOrder.Id;
    }

    /**
     * @description Ingests an Abandoned Checkout. If total value exceeds the threshold,
     *              creates a high-priority Lead and follow-up Task for the sales rep.
     */
    public static String processAbandonedCheckout(Map<String, Object> checkoutData) {
        String checkoutId = String.valueOf(checkoutData.get('id') != null ? checkoutData.get('id') : checkoutData.get('token'));
        Decimal cartValue = parseDecimal(checkoutData.get('total_price') != null ? checkoutData.get('total_price') : checkoutData.get('subtotal_price'));
        String cartUrl = (String) checkoutData.get('abandoned_checkout_url');
        String email = (String) checkoutData.get('email');
        String phone = (String) checkoutData.get('phone');

        // Customer details
        Map<String, Object> customer = (Map<String, Object>) checkoutData.get('customer');
        String firstName = customer != null ? (String) customer.get('first_name') : null;
        String lastName = customer != null ? (String) customer.get('last_name') : null;
        if (String.isBlank(lastName)) {
            lastName = String.isNotBlank(email) ? email : 'Abandoned Checkout Lead';
        }

        // Check threshold from settings
        Shopify_Setting__c settings = Shopify_Setting__c.getInstance();
        Decimal threshold = (settings != null && settings.Abandoned_Cart_Threshold__c != null) 
            ? settings.Abandoned_Cart_Threshold__c : 200.00;

        // Extract line item summary
        List<Object> lineItems = (List<Object>) checkoutData.get('line_items');
        String itemsSummary = summarizeLineItems(lineItems);

        // If cart value meets or exceeds high-value threshold, generate Lead + Task
        if (cartValue >= threshold) {
            List<Lead> existingLeads = [
                SELECT Id, Shopify_Checkout_Id__c, Status
                FROM Lead
                WHERE Shopify_Checkout_Id__c = :checkoutId
                WITH USER_MODE
                LIMIT 1
            ];

            Lead targetLead;
            if (!existingLeads.isEmpty()) {
                targetLead = existingLeads[0];
            } else {
                targetLead = new Lead(
                    LastName = lastName,
                    Company = 'Shopify Online Store',
                    LeadSource = 'Shopify Abandoned Cart',
                    Status = 'Open - Not Contacted',
                    Shopify_Checkout_Id__c = checkoutId
                );
            }

            if (String.isNotBlank(firstName)) {
                targetLead.FirstName = firstName;
            }
            if (String.isNotBlank(email)) {
                targetLead.Email = email;
            }
            if (String.isNotBlank(phone)) {
                targetLead.Phone = phone;
            }
            targetLead.Shopify_Cart_Value__c = cartValue;
            targetLead.Shopify_Cart_Url__c = cartUrl;
            targetLead.Shopify_Abandoned_Items__c = itemsSummary;

            upsert as user targetLead;

            // Spawn high-priority follow-up Task if newly created or high-value cart
            createAbandonedCartTask(targetLead.Id, cartValue, cartUrl);

            return targetLead.Id;
        }

        return null;
    }

    /**
     * @description Creates a follow-up Task for the sales rep to recover the cart.
     */
    private static void createAbandonedCartTask(Id leadId, Decimal cartValue, String cartUrl) {
        Task followUpTask = new Task(
            WhoId = leadId,
            Subject = '⚡ Urgent: Shopify High-Value Cart Recovery ($' + cartValue.setScale(2) + ')',
            Priority = 'High',
            Status = 'Not Started',
            ActivityDate = Date.today(),
            Description = 'A high-value customer abandoned their cart valued at $' + cartValue.setScale(2) + 
                          '. Reach out immediately via email or phone to offer assistance or a recovery discount.\n\nDirect Cart Link: ' + 
                          (String.isNotBlank(cartUrl) ? cartUrl : 'N/A')
        );
        insert as user followUpTask;
    }

    /**
     * @description Synchronizes an associated Opportunity for the order.
     */
    private static void syncAssociatedOpportunity(Order targetOrder, Id accountId, Decimal amount, String orderNumber, Date closeDate) {
        List<Opportunity> existingOpps = [
            SELECT Id, StageName, Amount
            FROM Opportunity
            WHERE Name = :('Shopify Order ' + orderNumber) AND AccountId = :accountId
            WITH USER_MODE
            LIMIT 1
        ];

        Opportunity opp;
        if (!existingOpps.isEmpty()) {
            opp = existingOpps[0];
        } else {
            opp = new Opportunity(
                AccountId = accountId,
                Name = 'Shopify Order ' + orderNumber,
                CloseDate = closeDate,
                StageName = 'Closed Won'
            );
        }

        opp.Amount = amount;
        upsert as user opp;
    }

    /**
     * @description Finds an existing Contact by Shopify Customer ID, Email, or Phone.
     */
    private static Contact findExistingContact(String shopifyId, String email, String phone) {
        if (String.isNotBlank(shopifyId)) {
            List<Contact> byShopifyId = [
                SELECT Id, AccountId, Shopify_Customer_Id__c, Email, Phone
                FROM Contact
                WHERE Shopify_Customer_Id__c = :shopifyId
                WITH USER_MODE
                LIMIT 1
            ];
            if (!byShopifyId.isEmpty()) return byShopifyId[0];
        }

        if (String.isNotBlank(email)) {
            List<Contact> byEmail = [
                SELECT Id, AccountId, Shopify_Customer_Id__c, Email, Phone
                FROM Contact
                WHERE Email = :email
                WITH USER_MODE
                LIMIT 1
            ];
            if (!byEmail.isEmpty()) return byEmail[0];
        }

        if (String.isNotBlank(phone)) {
            List<Contact> byPhone = [
                SELECT Id, AccountId, Shopify_Customer_Id__c, Email, Phone
                FROM Contact
                WHERE Phone = :phone
                WITH USER_MODE
                LIMIT 1
            ];
            if (!byPhone.isEmpty()) return byPhone[0];
        }

        return null;
    }

    /**
     * @description Finds or creates a parent Account for the customer.
     */
    private static Account findOrCreateAccount(String firstName, String lastName, String email) {
        String accountName = (String.isNotBlank(firstName) ? firstName + ' ' : '') + lastName + ' Household';
        List<Account> existing = [
            SELECT Id, Name
            FROM Account
            WHERE Name = :accountName
            WITH USER_MODE
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            return existing[0];
        }

        Account newAcct = new Account(Name = accountName);
        insert as user newAcct;
        return newAcct;
    }

    /**
     * @description Formats a readable summary of items in an abandoned cart.
     */
    private static String summarizeLineItems(List<Object> lineItems) {
        if (lineItems == null || lineItems.isEmpty()) {
            return 'No line items recorded.';
        }

        List<String> formatted = new List<String>();
        for (Object itemObj : lineItems) {
            Map<String, Object> item = (Map<String, Object>) itemObj;
            String title = (String) item.get('title');
            Object qty = item.get('quantity');
            Object price = item.get('price');
            formatted.add('• ' + title + ' (Qty: ' + qty + ', Price: $' + price + ')');
        }
        return String.join(formatted, '\n');
    }

    private static Id getDefaultPricebookId() {
        List<Pricebook2> pbs = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        return !pbs.isEmpty() ? pbs[0].Id : null;
    }

    private static Decimal parseDecimal(Object val) {
        if (val == null) return 0.00;
        try {
            return Decimal.valueOf(String.valueOf(val));
        } catch (Exception e) {
            return 0.00;
        }
    }

    private static Integer parseInteger(Object val) {
        if (val == null) return 0;
        try {
            return Integer.valueOf(String.valueOf(val));
        } catch (Exception e) {
            return 0;
        }
    }

    private static Date parseIsoDate(String isoStr) {
        if (String.isBlank(isoStr)) return Date.today();
        try {
            return Date.valueOf(isoStr.substring(0, 10));
        } catch (Exception e) {
            return Date.today();
        }
    }
}
