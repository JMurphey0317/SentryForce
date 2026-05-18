public with sharing class SentryMonitoringController {
    public class DashboardResponse {
        @AuraEnabled public List<Sentry_Event__c> events;
        @AuraEnabled public List<Sentry_Alert__c> alerts;
        @AuraEnabled public List<Sentry_Retrieval_Job__c> retrievalJobs;
        @AuraEnabled public SentrySettings.Configuration settings;
    }

    @AuraEnabled(cacheable=true)
    public static DashboardResponse getDashboard(String severityFilter, String sourceFilter, Integer limitSize) {
        Integer rowLimit = limitSize == null || limitSize <= 0 ? 25 : Math.min(limitSize, 200);
        String normalizedSeverity = String.isBlank(severityFilter) ? null : severityFilter;
        String normalizedSource = String.isBlank(sourceFilter) ? null : sourceFilter;
        String eventQuery =
            'SELECT Id, Alert_Status__c, Context__c, Duration_Ms__c, Event_Key__c, Event_Type__c, Message__c,' +
            ' Occurred_On__c, Record_Id__c, Retain_Until__c, Risk_Score__c, Rule_Matches__c, Severity__c,' +
            ' Source_Channel__c, Source_Type__c, Stack_Trace__c, Transaction_Id__c, User__r.Name' +
            ' FROM Sentry_Event__c';
        List<String> filters = new List<String>();
        if (normalizedSeverity != null) {
            filters.add('Severity__c = :normalizedSeverity');
        }
        if (normalizedSource != null) {
            filters.add('Source_Type__c = :normalizedSource');
        }
        if (!filters.isEmpty()) {
            eventQuery += ' WHERE ' + String.join(filters, ' AND ');
        }
        eventQuery += ' ORDER BY Occurred_On__c DESC NULLS LAST LIMIT :rowLimit';

        DashboardResponse response = new DashboardResponse();
        response.events = (List<Sentry_Event__c>) Database.query(eventQuery);
        response.alerts = [
            SELECT Id, Alert_Type__c, Message__c, Policy_Key__c, Risk_Score__c, Severity__c, Status__c,
                   Suggested_Action__c, Triggered_On__c, Sentry_Event__r.Event_Type__c, Sentry_Event__r.Context__c
            FROM Sentry_Alert__c
            ORDER BY Triggered_On__c DESC NULLS LAST
            LIMIT :rowLimit
        ];
        response.retrievalJobs = [
            SELECT Id, Completed_On__c, Error_Message__c, Event_Types__c, Matched_Log_Count__c,
                   Requested_End__c, Requested_Start__c, Status__c
            FROM Sentry_Retrieval_Job__c
            ORDER BY CreatedDate DESC
            LIMIT :rowLimit
        ];
        response.settings = SentrySettings.get();
        return response;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isLiveStreamEnabled() {
        return SentrySettings.get().enableLiveStream;
    }

    @AuraEnabled
    public static String queueElfRetrieval(List<String> eventTypes, String startDateTimeIso, String endDateTimeIso) {
        Datetime startDateTime = parseIsoDateTime(startDateTimeIso);
        Datetime endDateTime = parseIsoDateTime(endDateTimeIso);
        return String.valueOf(SentryMonitor.queueElfRetrieval(eventTypes == null ? new Set<String>() : new Set<String>(eventTypes), startDateTime, endDateTime));
    }

    @AuraEnabled
    public static void recordLightningPerformance(String pageName, Long durationMs, String detailJson) {
        SentryMonitor.trackLightningPerformance(pageName, durationMs, detailJson);
    }

    private static Datetime parseIsoDateTime(String isoValue) {
        if (String.isBlank(isoValue)) {
            return null;
        }
        String normalized = isoValue.replace('T', ' ').replace('Z', '');
        if (normalized.length() > 19) {
            normalized = normalized.substring(0, 19);
        }
        return Datetime.valueOfGmt(normalized);
    }
}
