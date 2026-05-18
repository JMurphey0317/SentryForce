# SentryForce

SentryForce is a Salesforce-native security monitoring and response framework that now combines:

- **SentryForce live event monitoring** for application, Apex, Lightning, Platform Events, CDC, and Event Monitoring telemetry
- **Transaction Security Policy recipes** for real-time blocking and alerting on risky Salesforce activity

This "best of both" repository brings together operational monitoring, anomaly scoring, alerting, Event Log File retrieval, and deployable Salesforce Transaction Security Policies in one repo.

## What is included

### Core SentryForce platform

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

### Transaction Security Policy module

This repo also includes deployable Flow-based **Transaction Security Policies** and supporting condition flows for practical Salesforce security controls such as:

- alerting on API anomaly events
- alerting on credential stuffing detections
- alerting on suspicious login anomalies
- alerting on session hijacking indicators
- alerting on guest user anomalies
- alerting on suspicious report activity
- alerting on critical permission assignments
- blocking Salesforce Inspector Reloaded bulk export behavior
- blocking attempts to grant Transaction Security exemptions

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
   - Salesforce Transaction Security Policies provide native real-time enforcement and alerts for selected event types.
   - `SentryPlugin` provides extension points for outbound integrations.
4. **Presentation**
   - `sentryMonitoringConsole` shows recent events, alerts, and retrieval jobs.
   - The console subscribes to `/event/Sentry_Event__e` for near-real-time refresh.

## Transaction Security Policies included

| Policy | Type | Event Monitored | Description |
|--------|------|-----------------|-------------|
| **Alert Critical Permission Assignment** | Alert | `PermissionSetEventStore` | Monitors critical permission assignments and alerts when assigned by non-approved automation/users |
| **Block Salesforce Inspector Reloaded Export** | Block | `ApiEvent` | Prevents mass data exports exceeding 2,000 rows via browser extensions |
| **Block Transaction Security Exemption** | Block | `PermissionSetEventStore` | Prevents creation/assignment of TransactionSecurityExempt-related permission changes |
| **Alert API Anomaly** | Alert | `ApiAnomalyEventStore` | Detects unusual API usage patterns and potential data scraping |
| **Alert Credential Stuffing** | Alert | `CredentialStuffingEventStore` | Identifies credential stuffing attacks using stolen credentials |
| **Alert Login Anomaly** | Alert | `LoginAnomalyEventStore` | Monitors login patterns for suspicious behavior |
| **Alert Session Hijacking** | Alert | `SessionHijackingEventStore` | Detects session hijacking via browser fingerprint analysis |
| **Alert Guest User Anomaly** | Alert | `GuestUserAnomalyEventStore` | Tracks data access anomalies from guest user permission misconfigurations |
| **Alert Report Anomaly** | Alert | `ReportAnomalyEventStore` | Monitors report access patterns for unusual data extraction |

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

## Event Monitoring + ELF retrieval flow

1. Open the **SentryForce Monitoring Console** tab.
2. Enter comma-separated Event Monitoring event types and an optional date range.
3. Click **Queue ELF Retrieval**.
4. `SentryElfRetrievalQueueable` queries `EventLogFile` metadata asynchronously.
5. Each matched log becomes a canonical `Sentry_Event__c` record with `Source_Channel__c = ELF`.
6. `Sentry_Retrieval_Job__c` is updated with match counts or retrieval errors.

## Setup

1. Deploy the metadata in `force-app` to a Salesforce org with Platform Events and Event Monitoring enabled.
2. Assign access to the custom objects, Apex classes, Lightning components, Flows, and Transaction Security Policies.
3. Add the **SentryForce Monitoring Console** tab to a Lightning app.
4. Schedule `SentryRetentionScheduler` for your preferred cleanup cadence.
5. Review and customize the policy notification recipients and flow conditions before enabling in production.
6. Test all blocking Transaction Security Policies in a sandbox first.

## Important notes for Transaction Security Policies

- Some imported policy metadata originally used placeholder or source-specific usernames for email notifications. Review the `<user>` values before deployment.
- `AlertLoginAnomaly.transactionSecurityPolicy-meta.xml` has been normalized to point to `PolicyCondition_AlertLoginAnomaly`.
- `AlertCriticalPermissionAs` still contains a sample CI/CD username condition (`cicd-username@company.com`) in its Flow logic and should be customized for your org.
- `BlockTransactionSecurityE` may require Salesforce platform behavior validation depending on org capabilities and release behavior.

## Tests

The repo includes focused Apex tests for:

- anomaly scoring (`SentryRiskEngine_Tests`)
- ingestion + alert creation (`SentryEventIngestionService_Tests`)
- retention purge logic (`SentryRetentionService_Tests`)
- ELF retrieval orchestration (`SentryElfRetrievalService_Tests`)
