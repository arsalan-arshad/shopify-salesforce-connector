import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getConnectorSettings from '@salesforce/apex/ShopifyConnectorController.getConnectorSettings';

import CONTACT_SHOPIFY_ID from '@salesforce/schema/Contact.Shopify_Customer_Id__c';
import CONTACT_TOTAL_SPENT from '@salesforce/schema/Contact.Shopify_Total_Spent__c';
import CONTACT_ORDER_COUNT from '@salesforce/schema/Contact.Shopify_Order_Count__c';

import ORDER_SHOPIFY_ID from '@salesforce/schema/Order.Shopify_Order_Id__c';
import ORDER_FINANCIAL_STATUS from '@salesforce/schema/Order.Shopify_Financial_Status__c';
import ORDER_FULFILLMENT_STATUS from '@salesforce/schema/Order.Shopify_Fulfillment_Status__c';

import LEAD_SHOPIFY_ID from '@salesforce/schema/Lead.Shopify_Checkout_Id__c';
import LEAD_CART_VALUE from '@salesforce/schema/Lead.Shopify_Cart_Value__c';
import LEAD_CART_URL from '@salesforce/schema/Lead.Shopify_Cart_Url__c';

export default class ShopifySyncBadge extends LightningElement {
  @api recordId;
  @api objectApiName;

  shopDomain = '';

  @wire(getConnectorSettings)
  wiredSettings({ data }) {
    if (data && data.shopDomain) {
      this.shopDomain = data.shopDomain;
    }
  }

  get fields() {
    if (this.objectApiName === 'Contact') {
      return [CONTACT_SHOPIFY_ID, CONTACT_TOTAL_SPENT, CONTACT_ORDER_COUNT];
    } else if (this.objectApiName === 'Order') {
      return [ORDER_SHOPIFY_ID, ORDER_FINANCIAL_STATUS, ORDER_FULFILLMENT_STATUS];
    } else if (this.objectApiName === 'Lead') {
      return [LEAD_SHOPIFY_ID, LEAD_CART_VALUE, LEAD_CART_URL];
    }
    return [];
  }

  @wire(getRecord, { recordId: '$recordId', fields: '$fields' })
  record;

  get isContact() {
    return this.objectApiName === 'Contact';
  }

  get isOrder() {
    return this.objectApiName === 'Order';
  }

  get isLead() {
    return this.objectApiName === 'Lead';
  }

  get shopifyId() {
    if (!this.record?.data) return null;
    if (this.isContact) return getFieldValue(this.record.data, CONTACT_SHOPIFY_ID);
    if (this.isOrder) return getFieldValue(this.record.data, ORDER_SHOPIFY_ID);
    if (this.isLead) return getFieldValue(this.record.data, LEAD_SHOPIFY_ID);
    return null;
  }

  get hasShopifyId() {
    return !!this.shopifyId;
  }

  get statusBadgeClass() {
    return this.hasShopifyId ? 'badge badge-synced' : 'badge badge-unlinked';
  }

  get statusText() {
    return this.hasShopifyId ? 'Synced with Shopify' : 'Not Linked';
  }

  get totalSpent() {
    const val = getFieldValue(this.record.data, CONTACT_TOTAL_SPENT);
    return val ? `$${Number(val).toFixed(2)}` : '$0.00';
  }

  get orderCount() {
    return getFieldValue(this.record.data, CONTACT_ORDER_COUNT) || 0;
  }

  get financialStatus() {
    return getFieldValue(this.record.data, ORDER_FINANCIAL_STATUS) || 'Pending';
  }

  get fulfillmentStatus() {
    return getFieldValue(this.record.data, ORDER_FULFILLMENT_STATUS) || 'Unfulfilled';
  }

  get cartValue() {
    const val = getFieldValue(this.record.data, LEAD_CART_VALUE);
    return val ? `$${Number(val).toFixed(2)}` : '$0.00';
  }

  get cartUrl() {
    return getFieldValue(this.record.data, LEAD_CART_URL);
  }

  handleOpenShopifyAdmin() {
    if (!this.shopDomain || !this.shopifyId) return;

    let resourcePath = '';
    if (this.isContact) resourcePath = `/admin/customers/${this.shopifyId}`;
    else if (this.isOrder) resourcePath = `/admin/orders/${this.shopifyId}`;
    else if (this.isLead) resourcePath = `/admin/checkouts/${this.shopifyId}`;

    const fullUrl = `https://${this.shopDomain}${resourcePath}`;
    window.open(fullUrl, '_blank');
  }

  handleOpenCartUrl() {
    if (this.cartUrl) {
      window.open(this.cartUrl, '_blank');
    }
  }
}
