public with sharing class SentryMonitor {
    private static final String EXCEPTION_STACK_TRACE_MESSAGE = '[EXCEPTION TYPE]: {0} | [LINE NUMBER]: {1} | [STACK TRACE]: {2}';
    @TestVisible private static List<Sentry_Event__e> bufferedEvents = new List<Sentry_Event__e>();

    public static void debug(String context, String message) {
        System.debug(LoggingLevel.DEBUG, '[' + context + '] ' + message);
    }

    public static void info(String context, String message) {
        publishEvent('Application', 'Apex', 'Info', context, null, message, null, null, null, null);
    }

    public static void warn(String context, String message) {
        publishEvent('Application', 'Apex', 'Warn', context, null, message, null, null, null, null);
    }

    public static void error(String context, String message) {
        publishEvent('Application', 'Apex', 'Error', context, null, message, null, null, null, null);
    }

    public static void critical(String context, String message) {
        publishEvent('Application', 'Apex', 'Critical', context, null, message, null, null, null, null);
    }

    public static void exception(String context, Exception exception) {
        publishEvent('Apex', 'Apex', 'Error', context, 'UnhandledException', exception.getMessage(), null, null, getFormattedExceptionStackTrace(exception), null);
    }

    public static void trackLightningPerformance(String pageName, Long durationMs, String detailJson) {
        publishEvent('Lightning', 'Lightning', 'Warn', pageName, 'LightningPerformance', 'Lightning page performance captured', durationMs, detailJson, null, null);
    }

    public static void trackApexExecution(String context, Long durationMs, String operation, String detailJson) {
        publishEvent('Apex', 'Apex', 'Info', context, String.isBlank(operation) ? 'ApexExecution' : operation, 'Apex execution telemetry captured', durationMs, detailJson, null, null);
    }

    public static void ingestPlatformTelemetry(String eventType, Map<String, Object> payload) {
        publishEvent('Platform Event', 'Platform Event', 'Info', 'PlatformEvent', eventType, 'Platform event telemetry captured', null, JSON.serialize(payload), null, null);
    }

    public static void ingestCdcTelemetry(String entityName, String changeType, Map<String, Object> payload) {
        publishEvent('CDC', 'CDC', 'Info', entityName, changeType, 'Change Data Capture telemetry captured', null, JSON.serialize(payload), null, null);
    }

    public static Id queueElfRetrieval(Set<String> eventTypes, Datetime startDateTime, Datetime endDateTime) {
        return SentryElfRetrievalService.queueRetrieval(eventTypes, startDateTime, endDateTime);
    }

    public static void bufferApplicationEvent(String sourceType, String sourceChannel, String severity, String context, String eventType, String message, Long durationMs, String payloadJson, String stackTrace, String retrievalJobId) {
        bufferedEvents.add(buildPlatformEvent(sourceType, sourceChannel, severity, context, eventType, message, durationMs, payloadJson, stackTrace, retrievalJobId));
    }

    public static void flushBufferedEvents() {
        if (bufferedEvents.isEmpty()) {
            return;
        }
        EventBus.publish(bufferedEvents);
        bufferedEvents.clear();
    }

    private static void publishEvent(String sourceType, String sourceChannel, String severity, String context, String eventType, String message, Long durationMs, String payloadJson, String stackTrace, String retrievalJobId) {
        Sentry_Event__e platformEvent = buildPlatformEvent(sourceType, sourceChannel, severity, context, eventType, message, durationMs, payloadJson, stackTrace, retrievalJobId);
        System.debug(LoggingLevel.INFO, platformEvent);
        EventBus.publish(platformEvent);
    }

    private static Sentry_Event__e buildPlatformEvent(String sourceType, String sourceChannel, String severity, String context, String eventType, String message, Long durationMs, String payloadJson, String stackTrace, String retrievalJobId) {
        Datetime occurredOn = System.now();
        return new Sentry_Event__e(
            Context__c = context,
            Duration_Ms__c = durationMs,
            Event_Key__c = String.join(new List<String>{ String.valueOf(occurredOn.getTime()), sourceType, eventType }, ':'),
            Event_Type__c = eventType,
            Message__c = message,
            Occurred_On__c = occurredOn,
            Payload__c = payloadJson,
            Retrieval_Job_Id__c = retrievalJobId,
            Severity__c = severity,
            Source_Channel__c = sourceChannel,
            Source_Type__c = sourceType,
            Stack_Trace__c = stackTrace,
            Transaction_Id__c = Limits.getTransactionId(),
            User_Id__c = UserInfo.getUserId()
        );
    }

    private static String getFormattedExceptionStackTrace(Exception exception) {
        return String.format(
            EXCEPTION_STACK_TRACE_MESSAGE,
            new List<String>{ exception.getTypeName(), String.valueOf(exception.getLineNumber()), exception.getStackTraceString() }
        );
    }
}
