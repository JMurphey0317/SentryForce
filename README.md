# SentryForce

SentryForce is a Salesforce-native live event monitoring framework that blends the lightweight platform-event logging pattern from Nova Salesforce Logger with the modular configuration, streaming UI, and extensibility patterns from Nebula Logger.

> Note: `DarkFenrir_Logger` and `Automation_Error_Log` were not accessible during implementation, so this repo integrates the strongest verifiable ideas from the accessible source repositories and leaves explicit extension hooks for additional private patterns.

## What is included

- Canonical **`Sentry_Event__c`** / **`Sentry_Alert__c`** / **`Sentry_Retrieval_Job__c`** data model
- High-volume **`Sentry_Event__e`** platform event ingestion pipeline with queueable persistence
- Static Apex facade (`SentryMonitor`) for application, Apex, Lightning, Platform Event, CDC, and ELF telemetry
- Configurable retention policy backed by **`Sentry_Monitor_Setting__mdt`**
- Rule/scoring-based anomaly detection for credential stuffing, session hijack indicators, suspicious exports, long-running Apex, and Lightning performance issues
- Alert record generation with plugin hooks (`SentryPlugin`) for future webhook/email/Slack channels
- Asynchronous **Event Log File (ELF)** retrieval workflow with job tracking
- LWC **`sentryMonitoringConsole`** for event viewing, filtering, alert visibility, and retrieval status
- Batch + scheduler retention cleanup for long-term compliance storage strategies
- Queueable finalizer hook for async exception capture

## Architecture

### Core layers

1. **Capture / Ingestion**
   - `SentryMonitor` publishes `Sentry_Event__e` records for app logs, Apex exceptions, CDC telemetry, performance timings, and Event Monitoring discoveries.
   - `SentryEventTrigger` fans platform events into `SentryEventIngestQueueable` for bulk-safe persistence.
2. **Storage / Retention**
   - `Sentry_Event__c` stores the canonical event envelope with risk score, payload, retention date, and source metadata.
   - `Sentry_Retrieval_Job__c` stores ELF retrieval lifecycle state.
   - `SentryRetentionBatch` and `SentryRetentionScheduler` purge expired events based on `Retain_Until__c`.
3. **Detection / Alerting**
   - `SentryRiskEngine` applies rule-based anomaly scoring.
   - `SentryAlertService` opens `Sentry_Alert__c` records for risky or high-severity events.
   - `SentryPlugin` provides triggerable/batchable extension points inspired by Nebula Logger.
4. **Presentation**
   - `sentryMonitoringConsole` shows recent events, alerts, and retrieval jobs.
   - The console subscribes to `/event/Sentry_Event__e` for near-real-time refresh.

## Data model

### `Sentry_Event__c`

The canonical event record stores:

- source type/channel (`Application`, `Platform Event`, `CDC`, `Event Monitoring`, `ELF`, `Lightning`, `Apex`)
- severity and alert status
- message, context, payload JSON, stack trace, and transaction ID
- calculated risk score and matched anomaly rules
- retention date for purge/archival workflows
- optional lookup to an ELF retrieval job

### `Sentry_Alert__c`

Alert records track:

- alert type and severity
- policy key / event type
- suggested response
- current status (Open, Acknowledged, Closed)
- related `Sentry_Event__c`

### `Sentry_Retrieval_Job__c`

Retrieval jobs support:

- requested ELF date range and event type filters
- asynchronous status tracking
- matched log counts
- retrieval failure details

## Configuration

`Sentry_Monitor_Setting__mdt.Default` ships with baseline settings:

- `Default_Retention_Days__c` = 90
- `Event_Monitoring_Retention_Days__c` = 365
- `Alert_Risk_Score_Threshold__c` = 70
- `Login_Failure_Threshold__c` = 5
- `Bulk_Download_Threshold__c` = 200
- `Apex_Performance_Threshold_Ms__c` = 3000
- `Page_Performance_Threshold_Ms__c` = 2500
- `Off_Hours_Start__c` / `Off_Hours_End__c` = `22:00` / `06:00`
- `Enable_Live_Stream__c`, `Enable_Event_Monitoring__c`, `Enable_Alerts__c`

### Retention guidance

- Application / platform telemetry uses `Default_Retention_Days__c`.
- Event Monitoring and ELF discoveries use `Event_Monitoring_Retention_Days__c` for long-term audit retention.
- Extend `SentryRetentionBatch` or plug in a custom archiver to move expired records into a Big Object or external lakehouse before deletion.

## Event Monitoring + ELF retrieval flow

1. Open the **SentryForce Monitoring Console** tab.
2. Enter comma-separated Event Monitoring event types and an optional date range.
3. Click **Queue ELF Retrieval**.
4. `SentryElfRetrievalQueueable` queries `EventLogFile` metadata asynchronously.
5. Each matched log becomes a canonical `Sentry_Event__c` record with `Source_Channel__c = ELF`.
6. `Sentry_Retrieval_Job__c` is updated with match counts or retrieval errors.

This gives admins a point-and-click retrieval workflow while keeping the storage and alerting pipeline unified.

## Threat detection hooks

`SentryRiskEngine` currently scores practical, explainable detections:

- credential stuffing based on login failure counts
- session hijack indicators (for example IP mismatch flags)
- suspicious report/export/download behavior
- off-hours risky activity
- Lightning page performance regressions
- long-running Apex executions and unhandled exceptions

The scoring engine is deliberately simple and testable. Future ML integrations can add new risk enrichments before persistence or implement a `SentryPlugin.Triggerable` channel.

## Apex + Lightning usage examples

### Application logging

```apex
SentryMonitor.info('CaseService', 'Case update processed successfully');
SentryMonitor.warn('PaymentGateway', 'Retry threshold approaching');
SentryMonitor.error('FulfillmentSync', 'Downstream ERP returned an error');
```

### Exception logging

```apex
try {
    update recordsToSave;
} catch (Exception ex) {
    SentryMonitor.exception('OrderSyncJob', ex);
}
```

### Apex execution tracking

```apex
Long started = DateTime.now().getTime();
// perform work
SentryMonitor.trackApexExecution(
    'NightlySettlementBatch',
    DateTime.now().getTime() - started,
    'SettlementRun',
    JSON.serialize(new Map<String, Object>{ 'recordsProcessed' => 1200 })
);
```

### CDC and platform event telemetry hooks

```apex
SentryMonitor.ingestPlatformTelemetry('Order_Status_Changed__e', payload);
SentryMonitor.ingestCdcTelemetry('Account', 'UPDATE', payload);
```

### Lightning performance tracking

Add the `sentryMonitoringConsole` LWC to an app/home page or reuse the `recordLightningPerformance` Apex method from a custom LWC to emit page timing data into the same event pipeline.

## Setup

1. Deploy the metadata in `force-app` to a Salesforce org with Platform Events and Event Monitoring enabled.
2. Assign access to the custom objects, Apex classes, and the `sentryMonitoringConsole` tab.
3. Add the **SentryForce Monitoring Console** tab to a Lightning app.
4. Schedule `SentryRetentionScheduler` for your preferred cleanup cadence.
5. Create `Sentry_Plugin__mdt` records for any outbound notification classes you want to attach.

## Tests

The repo includes focused Apex tests for:

- anomaly scoring (`SentryRiskEngine_Tests`)
- ingestion + alert creation (`SentryEventIngestionService_Tests`)
- retention purge logic (`SentryRetentionService_Tests`)
- ELF retrieval orchestration (`SentryElfRetrievalService_Tests`)

## Source inspiration

- **Nova Salesforce Logger**: simple platform-event-to-record logging, formula-driven flags, retention scheduler
- **Nebula Logger**: plugin architecture, typed configuration, asynchronous failure hooks, live event streaming, and admin UI patterns
