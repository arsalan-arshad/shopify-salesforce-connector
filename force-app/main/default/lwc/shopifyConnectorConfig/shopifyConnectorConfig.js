import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConnectorSettings from '@salesforce/apex/ShopifyConnectorController.getConnectorSettings';
import saveConnectorSettings from '@salesforce/apex/ShopifyConnectorController.saveConnectorSettings';
import getSyncStats from '@salesforce/apex/ShopifyConnectorController.getSyncStats';
import getRecentLogs from '@salesforce/apex/ShopifyConnectorController.getRecentLogs';
import replayLog from '@salesforce/apex/ShopifyConnectorController.replayLog';
import bulkReplayFailed from '@salesforce/apex/ShopifyConnectorController.bulkReplayFailed';
import simulateWebhook from '@salesforce/apex/ShopifyConnectorController.simulateWebhook';

export default class ShopifyConnectorConfig extends LightningElement {
  @track settings = {};
  @track form = {
    shopDomain: '',
    sharedSecret: '',
    adminAccessToken: '',
    abandonedCartThreshold: 200.0,
    enableBidirectionalFulfillment: true,
    autoCreateOpportunity: true,
    syncActive: true
  };
  @track stats = {
    total24h: 0,
    success24h: 0,
    failed24h: 0,
    totalPendingDlq: 0,
    successRate: 100.0
  };
  @track logs = [];
  @track statusFilter = 'All';
  @track isSaving = false;
  @track isReplaying = false;
  @track isSimulating = false;

  simulatorTopic = 'orders/create';
  simulatorPayload = JSON.stringify(
    {
      id: 882910,
      name: '#1055',
      total_price: '280.00',
      financial_status: 'paid',
      fulfillment_status: 'unfulfilled',
      customer: {
        id: 44012,
        first_name: 'Alex',
        last_name: 'Rivers',
        email: 'alex.rivers@example.com'
      }
    },
    null,
    2
  );

  filterOptions = [
    { label: 'All Statuses', value: 'All' },
    { label: 'Failed Only (DLQ)', value: 'Failed' },
    { label: 'Success Only', value: 'Success' },
    { label: 'Replayed Only', value: 'Replayed' }
  ];

  simulatorTopicOptions = [
    { label: 'orders/create', value: 'orders/create' },
    { label: 'customers/create', value: 'customers/create' },
    { label: 'checkouts/create (Abandoned Cart)', value: 'checkouts/create' }
  ];

  connectedCallback() {
    this.loadSettings();
    this.loadStats();
    this.loadLogs();
  }

  async loadSettings() {
    try {
      const data = await getConnectorSettings();
      if (data) {
        this.settings = data;
        this.form = {
          shopDomain: data.shopDomain || '',
          sharedSecret: '',
          adminAccessToken: '',
          abandonedCartThreshold: data.abandonedCartThreshold || 200.0,
          enableBidirectionalFulfillment: data.enableBidirectionalFulfillment !== false,
          autoCreateOpportunity: data.autoCreateOpportunity !== false,
          syncActive: data.syncActive !== false
        };
      }
    } catch (error) {
      this.showToast('Error Loading Settings', error?.body?.message || error.message, 'error');
    }
  }

  async loadStats() {
    try {
      const data = await getSyncStats();
      if (data) {
        this.stats = data;
      }
    } catch (error) {
      console.error('Error loading stats:', error);
    }
  }

  async loadLogs() {
    try {
      const data = await getRecentLogs({ limitCount: 50, statusFilter: this.statusFilter });
      this.logs = data || [];
    } catch (error) {
      console.error('Error loading logs:', error);
    }
  }

  get hasLogs() {
    return this.logs && this.logs.length > 0;
  }

  get formattedLogs() {
    return this.logs.map((log) => {
      let badgeClass = 'status-badge status-default';
      if (log.Status__c === 'Success') badgeClass = 'status-badge status-success';
      else if (log.Status__c === 'Failed') badgeClass = 'status-badge status-failed';
      else if (log.Status__c === 'Replayed') badgeClass = 'status-badge status-replayed';

      const dir = log.Direction__c === 'Outbound_To_Shopify' ? 'Outbound ↗' : 'Inbound ↙';
      const created = log.CreatedDate ? new Date(log.CreatedDate).toLocaleTimeString() : '';

      return {
        ...log,
        badgeClass,
        directionFormatted: dir,
        createdFormatted: created
      };
    });
  }

  get sharedSecretPlaceholder() {
    return this.settings.hasSharedSecret ? '•••••••••••••••• (Saved)' : 'Enter Shopify Webhook Secret';
  }

  get adminTokenPlaceholder() {
    return this.settings.hasAdminToken ? '•••••••••••••••• (Saved)' : 'shpat_... Admin Access Token';
  }

  get syncStatusLabel() {
    return this.form.syncActive ? 'Active' : 'Disabled';
  }

  get syncStatusBadgeClass() {
    return this.form.syncActive ? 'status-pill pill-active' : 'status-pill pill-disabled';
  }

  get shopDomainDisplay() {
    return this.form.shopDomain || 'No Store Configured';
  }

  handleInputChange(event) {
    const field = event.target.dataset.field;
    this.form[field] = event.target.value;
  }

  handleToggleChange(event) {
    const field = event.target.dataset.field;
    this.form[field] = event.target.checked;
  }

  handleFilterChange(event) {
    this.statusFilter = event.detail.value;
    this.loadLogs();
  }

  handleRefresh() {
    this.loadStats();
    this.loadLogs();
    this.showToast('Refreshed', 'Dashboard metrics and logs updated.', 'info');
  }

  async handleSaveSettings() {
    this.isSaving = true;
    try {
      await saveConnectorSettings({ config: this.form });
      this.showToast('Success', 'Shopify connector settings successfully saved.', 'success');
      await this.loadSettings();
    } catch (error) {
      this.showToast('Save Failed', error?.body?.message || error.message, 'error');
    } finally {
      this.isSaving = false;
    }
  }

  async handleReplaySingle(event) {
    const logId = event.target.dataset.id;
    this.isReplaying = true;
    try {
      const res = await replayLog({ logId });
      if (res.success) {
        this.showToast('Replayed', res.message, 'success');
        this.loadStats();
        this.loadLogs();
      } else {
        this.showToast('Replay Failed', res.message, 'error');
      }
    } catch (error) {
      this.showToast('Error', error?.body?.message || error.message, 'error');
    } finally {
      this.isReplaying = false;
    }
  }

  async handleBulkReplay() {
    this.isReplaying = true;
    try {
      const res = await bulkReplayFailed();
      this.showToast(
        'Bulk Replay Completed',
        `Processed ${res.totalProcessed} failed events: ${res.replayedCount} replayed, ${res.failedCount} errors.`,
        res.failedCount === 0 ? 'success' : 'warning'
      );
      this.loadStats();
      this.loadLogs();
    } catch (error) {
      this.showToast('Error', error?.body?.message || error.message, 'error');
    } finally {
      this.isReplaying = false;
    }
  }

  handleCopyWebhookUrl() {
    if (this.settings.webhookEndpoint) {
      navigator.clipboard.writeText(this.settings.webhookEndpoint);
      this.showToast('Copied to Clipboard', 'Webhook URL copied.', 'success');
    }
  }

  handleSimulatorTopicChange(event) {
    this.simulatorTopic = event.detail.value;
    if (this.simulatorTopic === 'customers/create') {
      this.simulatorPayload = JSON.stringify(
        {
          id: 770123,
          first_name: 'Morgan',
          last_name: 'Chase',
          email: 'morgan.chase@example.com',
          phone: '+15554321098',
          total_spent: '750.00',
          orders_count: 3
        },
        null,
        2
      );
    } else if (this.simulatorTopic === 'checkouts/create') {
      this.simulatorPayload = JSON.stringify(
        {
          id: 'chk_sim_8819',
          total_price: '385.00',
          email: 'shopper@example.com',
          abandoned_checkout_url: 'https://store.myshopify.com/checkouts/chk_sim_8819/recover',
          customer: { first_name: 'Taylor', last_name: 'Swiftly' },
          line_items: [{ title: 'Silk Cashmere Sweater', quantity: 1, price: '385.00' }]
        },
        null,
        2
      );
    } else {
      this.simulatorPayload = JSON.stringify(
        {
          id: 882910,
          name: '#1055',
          total_price: '280.00',
          financial_status: 'paid',
          customer: { id: 44012, first_name: 'Alex', last_name: 'Rivers', email: 'alex.rivers@example.com' }
        },
        null,
        2
      );
    }
  }

  handleSimulatorPayloadChange(event) {
    this.simulatorPayload = event.target.value;
  }

  async handleDispatchSimulation() {
    this.isSimulating = true;
    try {
      const res = await simulateWebhook({
        topic: this.simulatorTopic,
        payload: this.simulatorPayload
      });

      if (res.success) {
        this.showToast('Simulation Success', `Event processed! Record ID: ${res.recordId || 'N/A'}`, 'success');
        this.loadStats();
        this.loadLogs();
      } else {
        this.showToast('Simulation Failed', res.errorMessage, 'error');
      }
    } catch (error) {
      this.showToast('Error', error?.body?.message || error.message, 'error');
    } finally {
      this.isSimulating = false;
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
