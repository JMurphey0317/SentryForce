public with sharing class SentrySettings {
    public class Configuration {
        @AuraEnabled public Integer defaultRetentionDays;
        @AuraEnabled public Integer eventMonitoringRetentionDays;
        @AuraEnabled public Integer alertRiskScoreThreshold;
        @AuraEnabled public Integer loginFailureThreshold;
        @AuraEnabled public Integer bulkDownloadThreshold;
        @AuraEnabled public Integer apexPerformanceThresholdMs;
        @AuraEnabled public Integer pagePerformanceThresholdMs;
        @AuraEnabled public Boolean enableLiveStream;
        @AuraEnabled public Boolean enableEventMonitoring;
        @AuraEnabled public Boolean enableAlerts;
        @AuraEnabled public String offHoursStart;
        @AuraEnabled public String offHoursEnd;

        public Configuration() {
            defaultRetentionDays = 90;
            eventMonitoringRetentionDays = 365;
            alertRiskScoreThreshold = 70;
            loginFailureThreshold = 5;
            bulkDownloadThreshold = 200;
            apexPerformanceThresholdMs = 3000;
            pagePerformanceThresholdMs = 2500;
            enableLiveStream = true;
            enableEventMonitoring = true;
            enableAlerts = true;
            offHoursStart = '22:00';
            offHoursEnd = '06:00';
        }
    }

    @TestVisible
    private static Configuration mockConfiguration;

    public static Configuration get() {
        if (Test.isRunningTest() && mockConfiguration != null) {
            return mockConfiguration;
        }

        Configuration config = new Configuration();
        Sentry_Monitor_Setting__mdt record = Sentry_Monitor_Setting__mdt.getInstance('Default');
        if (record == null) {
            return config;
        }

        if (record.Default_Retention_Days__c != null) {
            config.defaultRetentionDays = Integer.valueOf(record.Default_Retention_Days__c);
        }
        if (record.Event_Monitoring_Retention_Days__c != null) {
            config.eventMonitoringRetentionDays = Integer.valueOf(record.Event_Monitoring_Retention_Days__c);
        }
        if (record.Alert_Risk_Score_Threshold__c != null) {
            config.alertRiskScoreThreshold = Integer.valueOf(record.Alert_Risk_Score_Threshold__c);
        }
        if (record.Login_Failure_Threshold__c != null) {
            config.loginFailureThreshold = Integer.valueOf(record.Login_Failure_Threshold__c);
        }
        if (record.Bulk_Download_Threshold__c != null) {
            config.bulkDownloadThreshold = Integer.valueOf(record.Bulk_Download_Threshold__c);
        }
        if (record.Apex_Performance_Threshold_Ms__c != null) {
            config.apexPerformanceThresholdMs = Integer.valueOf(record.Apex_Performance_Threshold_Ms__c);
        }
        if (record.Page_Performance_Threshold_Ms__c != null) {
            config.pagePerformanceThresholdMs = Integer.valueOf(record.Page_Performance_Threshold_Ms__c);
        }
        config.enableLiveStream = record.Enable_Live_Stream__c;
        config.enableEventMonitoring = record.Enable_Event_Monitoring__c;
        config.enableAlerts = record.Enable_Alerts__c;
        config.offHoursStart = String.isBlank(record.Off_Hours_Start__c) ? config.offHoursStart : record.Off_Hours_Start__c;
        config.offHoursEnd = String.isBlank(record.Off_Hours_End__c) ? config.offHoursEnd : record.Off_Hours_End__c;
        return config;
    }

    public static Time parseTime(String value, Time fallbackValue) {
        if (String.isBlank(value)) {
            return fallbackValue;
        }

        List<String> parts = value.split(':');
        if (parts.size() != 2) {
            return fallbackValue;
        }

        try {
            return Time.newInstance(Integer.valueOf(parts[0]), Integer.valueOf(parts[1]), 0, 0);
        } catch (Exception ex) {
            return fallbackValue;
        }
    }

    @TestVisible
    static void setMock(Configuration configuration) {
        mockConfiguration = configuration;
    }
}
