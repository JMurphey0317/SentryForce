public with sharing class SentryEventIngestionService {
    public class SentryEventRequest {
        public String context;
        public Long durationMs;
        public String eventKey;
        public String eventType;
        public String message;
        public Datetime occurredOn;
        public String payloadJson;
        public String recordId;
        public String retrievalJobId;
        public String severity;
        public String sourceChannel;
        public String sourceType;
        public String stackTrace;
        public String transactionId;
        public String userId;

        public static SentryEventRequest fromPlatformEvent(Sentry_Event__e eventRecord) {
            SentryEventRequest request = new SentryEventRequest();
            request.context = eventRecord.Context__c;
            request.durationMs = eventRecord.Duration_Ms__c == null ? null : Long.valueOf(String.valueOf(eventRecord.Duration_Ms__c));
            request.eventKey = eventRecord.Event_Key__c;
            request.eventType = eventRecord.Event_Type__c;
            request.message = eventRecord.Message__c;
            request.occurredOn = eventRecord.Occurred_On__c;
            request.payloadJson = eventRecord.Payload__c;
            request.recordId = eventRecord.Record_Id__c;
            request.retrievalJobId = eventRecord.Retrieval_Job_Id__c;
            request.severity = eventRecord.Severity__c;
            request.sourceChannel = eventRecord.Source_Channel__c;
            request.sourceType = eventRecord.Source_Type__c;
            request.stackTrace = eventRecord.Stack_Trace__c;
            request.transactionId = eventRecord.Transaction_Id__c;
            request.userId = eventRecord.User_Id__c;
            return request;
        }

        public Sentry_Event__c toEventRecord(SentryRiskEngine.Result result) {
            return new Sentry_Event__c(
                Alert_Status__c = result.shouldAlert(SentrySettings.get()) ? 'Open' : 'None',
                Context__c = context,
                Duration_Ms__c = durationMs,
                Event_Key__c = String.isBlank(eventKey) ? buildEventKey() : eventKey,
                Event_Type__c = eventType,
                Message__c = message,
                Occurred_On__c = occurredOn == null ? System.now() : occurredOn,
                Payload__c = payloadJson,
                Record_Id__c = recordId,
                Retrieval_Job__c = toId(retrievalJobId),
                Retain_Until__c = SentryRetentionService.calculateRetentionDate(sourceType, occurredOn == null ? System.now() : occurredOn),
                Risk_Score__c = result.score,
                Rule_Matches__c = result.summary(),
                Severity__c = String.isBlank(severity) ? 'Info' : severity,
                Source_Channel__c = sourceChannel,
                Source_Type__c = sourceType,
                Stack_Trace__c = stackTrace,
                Transaction_Id__c = transactionId,
                User__c = toId(userId)
            );
        }

        private String buildEventKey() {
            List<String> parts = new List<String>{ String.valueOf(occurredOn), sourceType, eventType, transactionId };
            return String.join(parts, ':');
        }

        private static Id toId(String value) {
            if (String.isBlank(value) || (value.length() != 15 && value.length() != 18)) {
                return null;
            }
            return (Id) value;
        }
    }

    public static void handlePlatformEvents(List<Sentry_Event__e> platformEvents) {
        if (platformEvents.isEmpty()) {
            return;
        }
        List<SentryEventRequest> requests = new List<SentryEventRequest>();
        for (Sentry_Event__e eventRecord : platformEvents) {
            requests.add(SentryEventRequest.fromPlatformEvent(eventRecord));
        }
        System.enqueueJob(new SentryEventIngestQueueable(requests));
    }

    public static List<Sentry_Event__c> persist(List<SentryEventRequest> requests) {
        if (requests.isEmpty()) {
            return new List<Sentry_Event__c>();
        }

        SentrySettings.Configuration settings = SentrySettings.get();
        List<SentryRiskEngine.Result> results = new List<SentryRiskEngine.Result>();
        List<Sentry_Event__c> events = new List<Sentry_Event__c>();
        for (SentryEventRequest request : requests) {
            SentryRiskEngine.Result result = SentryRiskEngine.evaluate(request, settings);
            results.add(result);
            events.add(request.toEventRecord(result));
        }

        insert events;

        List<Sentry_Alert__c> alerts = SentryAlertService.buildAlerts(events, requests, results, settings);
        if (!alerts.isEmpty()) {
            insert alerts;
            SentryAlertService.dispatch(events, alerts);
        }
        return events;
    }
}
