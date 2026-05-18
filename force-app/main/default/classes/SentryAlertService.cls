public with sharing class SentryAlertService {
    public static List<Sentry_Alert__c> buildAlerts(
        List<Sentry_Event__c> events,
        List<SentryEventIngestionService.SentryEventRequest> requests,
        List<SentryRiskEngine.Result> results,
        SentrySettings.Configuration settings
    ) {
        List<Sentry_Alert__c> alerts = new List<Sentry_Alert__c>();
        for (Integer index = 0; index < events.size(); index++) {
            SentryRiskEngine.Result result = results[index];
            if (!result.shouldAlert(settings)) {
                continue;
            }
            Sentry_Event__c eventRecord = events[index];
            alerts.add(new Sentry_Alert__c(
                Sentry_Event__c = eventRecord.Id,
                Alert_Type__c = result.alertType,
                Message__c = String.isBlank(eventRecord.Message__c) ? eventRecord.Event_Type__c : eventRecord.Message__c,
                Policy_Key__c = eventRecord.Event_Type__c,
                Risk_Score__c = eventRecord.Risk_Score__c,
                Severity__c = resolveSeverity(result.score),
                Status__c = 'Open',
                Suggested_Action__c = buildSuggestedAction(result, requests[index]),
                Triggered_On__c = System.now()
            ));
        }
        return alerts;
    }

    public static void dispatch(List<Sentry_Event__c> events, List<Sentry_Alert__c> alerts) {
        if (alerts.isEmpty()) {
            return;
        }
        for (Sentry_Plugin__mdt configuration : SentryPlugin.getPluginConfigurations()) {
            SentryPlugin.Triggerable plugin = SentryPlugin.newTriggerableInstance(configuration.Apex_Class__c);
            if (plugin != null) {
                plugin.execute(configuration, events, alerts);
            }
        }
    }

    private static String resolveSeverity(Integer score) {
        if (score >= 90) {
            return 'Critical';
        }
        if (score >= 70) {
            return 'High';
        }
        if (score >= 40) {
            return 'Medium';
        }
        return 'Low';
    }

    private static String buildSuggestedAction(SentryRiskEngine.Result result, SentryEventIngestionService.SentryEventRequest request) {
        if (result.alertType == 'Credential Stuffing') {
            return 'Review login history, Transaction Security Policies, and MFA posture for the impacted user or integration.';
        }
        if (result.alertType == 'Session Hijack') {
            return 'Validate session source IP/device, revoke active sessions if needed, and investigate browser/token anomalies.';
        }
        if (result.alertType == 'Suspicious Export') {
            return 'Review report and data export permissions, and consider blocking the action with Transaction Security or Flow automation.';
        }
        if (result.alertType == 'Lightning Performance' || result.alertType == 'Apex Performance') {
            return 'Inspect recent deployments, governor usage, and the related page or Apex transaction for regressions.';
        }
        if (String.isNotBlank(request.stackTrace)) {
            return 'Inspect the stored stack trace and related telemetry, then route to the owning engineering or operations team.';
        }
        return 'Review the event payload and policy thresholds, then acknowledge or escalate the alert.';
    }
}
