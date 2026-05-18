public with sharing class SentryRetentionService {
    public static Date calculateRetentionDate(String sourceType, Datetime occurredOn) {
        SentrySettings.Configuration settings = SentrySettings.get();
        Integer retentionDays = (sourceType == 'Event Monitoring' || sourceType == 'ELF')
            ? settings.eventMonitoringRetentionDays
            : settings.defaultRetentionDays;
        Date eventDate = occurredOn == null ? System.today() : occurredOn.date();
        return eventDate.addDays(retentionDays);
    }

    public static Integer purgeExpiredEvents(Integer batchSize) {
        Integer safeBatchSize = batchSize == null || batchSize <= 0 ? 200 : Math.min(batchSize, 10000);
        List<Sentry_Event__c> expiredEvents = [
            SELECT Id
            FROM Sentry_Event__c
            WHERE Retain_Until__c < :System.today()
            ORDER BY Retain_Until__c ASC
            LIMIT :safeBatchSize
        ];
        if (expiredEvents.isEmpty()) {
            return 0;
        }
        Database.delete(expiredEvents, false);
        return expiredEvents.size();
    }
}
