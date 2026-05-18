import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe } from 'lightning/empApi';
import getDashboard from '@salesforce/apex/SentryMonitoringController.getDashboard';
import queueElfRetrieval from '@salesforce/apex/SentryMonitoringController.queueElfRetrieval';
import recordLightningPerformance from '@salesforce/apex/SentryMonitoringController.recordLightningPerformance';

const DEFAULT_SETTINGS = {
  alertRiskScoreThreshold: 70,
  defaultRetentionDays: 90,
  eventMonitoringRetentionDays: 365,
  enableLiveStream: true
};

export default class SentryMonitoringConsole extends LightningElement {
  @track events = [];
  @track alerts = [];
  @track retrievalJobs = [];
  @track settings = DEFAULT_SETTINGS;
  @track severityFilter = '';
  @track sourceFilter = '';
  @track eventTypesInput = 'Login, ReportExport';
  @track retrievalStart = '';
  @track retrievalEnd = '';
  @track errorMessage;

  eventColumns = [
    { label: 'Occurred', fieldName: 'Occurred_On__c', type: 'date' },
    { label: 'Source', fieldName: 'Source_Type__c' },
    { label: 'Type', fieldName: 'Event_Type__c' },
    { label: 'Severity', fieldName: 'Severity__c' },
    { label: 'Risk', fieldName: 'Risk_Score__c', type: 'number' },
    { label: 'Alert', fieldName: 'Alert_Status__c' },
    { label: 'Message', fieldName: 'Message__c' }
  ];

  alertColumns = [
    { label: 'Triggered', fieldName: 'Triggered_On__c', type: 'date' },
    { label: 'Type', fieldName: 'Alert_Type__c' },
    { label: 'Severity', fieldName: 'Severity__c' },
    { label: 'Risk', fieldName: 'Risk_Score__c', type: 'number' },
    { label: 'Status', fieldName: 'Status__c' },
    { label: 'Message', fieldName: 'Message__c' }
  ];

  retrievalColumns = [
    { label: 'Requested Start', fieldName: 'Requested_Start__c', type: 'date' },
    { label: 'Requested End', fieldName: 'Requested_End__c', type: 'date' },
    { label: 'Event Types', fieldName: 'Event_Types__c' },
    { label: 'Matches', fieldName: 'Matched_Log_Count__c', type: 'number' },
    { label: 'Status', fieldName: 'Status__c' },
    { label: 'Error', fieldName: 'Error_Message__c' }
  ];

  severityOptions = [
    { label: 'All severities', value: '' },
    { label: 'Info', value: 'Info' },
    { label: 'Warn', value: 'Warn' },
    { label: 'Error', value: 'Error' },
    { label: 'Critical', value: 'Critical' }
  ];

  sourceOptions = [
    { label: 'All sources', value: '' },
    { label: 'Application', value: 'Application' },
    { label: 'Platform Event', value: 'Platform Event' },
    { label: 'CDC', value: 'CDC' },
    { label: 'Event Monitoring', value: 'Event Monitoring' },
    { label: 'Lightning', value: 'Lightning' },
    { label: 'Apex', value: 'Apex' }
  ];

  loadStartedAt;
  subscription;

  connectedCallback() {
    this.loadStartedAt = performance.now();
    this.loadDashboard();
  }

  disconnectedCallback() {
    if (this.subscription) {
      unsubscribe(this.subscription, () => {});
    }
  }

  get streamStatusLabel() {
    return this.settings.enableLiveStream ? 'Enabled' : 'Disabled';
  }

  async loadDashboard() {
    try {
      const response = await getDashboard({
        severityFilter: this.severityFilter,
        sourceFilter: this.sourceFilter,
        limitSize: 25
      });
      this.events = response.events;
      this.alerts = response.alerts;
      this.retrievalJobs = response.retrievalJobs;
      this.settings = response.settings || DEFAULT_SETTINGS;
      this.errorMessage = undefined;
      if (this.settings.enableLiveStream && !this.subscription) {
        this.registerStream();
      }
      this.capturePerformance();
    } catch (error) {
      this.handleError(error);
    }
  }

  async registerStream() {
    this.subscription = await subscribe('/event/Sentry_Event__e', -1, () => {
      this.loadDashboard();
    });
  }

  async capturePerformance() {
    if (!this.loadStartedAt) {
      return;
    }
    const durationMs = Math.round(performance.now() - this.loadStartedAt);
    this.loadStartedAt = undefined;
    try {
      await recordLightningPerformance({
        pageName: 'SentryForce Monitoring Console',
        durationMs,
        detailJson: JSON.stringify({
          userAgent: navigator.userAgent,
          viewport: `${window.innerWidth}x${window.innerHeight}`
        })
      });
    } catch (error) {
      // Performance telemetry is best-effort; ignore Apex errors here to avoid blocking the UI.
      // eslint-disable-next-line no-console
      console.warn(error);
    }
  }

  handleSeverityChange(event) {
    this.severityFilter = event.detail.value;
    this.loadDashboard();
  }

  handleSourceChange(event) {
    this.sourceFilter = event.detail.value;
    this.loadDashboard();
  }

  handleEventTypesChange(event) {
    this.eventTypesInput = event.detail.value;
  }

  handleRetrievalStartChange(event) {
    this.retrievalStart = event.detail.value;
  }

  handleRetrievalEndChange(event) {
    this.retrievalEnd = event.detail.value;
  }

  async handleQueueRetrieval() {
    try {
      await queueElfRetrieval({
        eventTypes: this.eventTypesInput
          .split(',')
          .map(value => value.trim())
          .filter(Boolean),
        startDateTimeIso: this.retrievalStart ? new Date(this.retrievalStart).toISOString() : null,
        endDateTimeIso: this.retrievalEnd ? new Date(this.retrievalEnd).toISOString() : null
      });
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'ELF retrieval queued',
          message: 'SentryForce will ingest matching Event Log File metadata asynchronously.',
          variant: 'success'
        })
      );
      this.loadDashboard();
    } catch (error) {
      this.handleError(error);
    }
  }

  handleError(error) {
    const message = error?.body?.message || error?.message || 'Unexpected error';
    this.errorMessage = message;
    this.dispatchEvent(
      new ShowToastEvent({
        title: 'SentryForce error',
        message,
        variant: 'error'
      })
    );
  }
}
