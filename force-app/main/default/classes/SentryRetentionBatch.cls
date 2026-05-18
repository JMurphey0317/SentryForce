public with sharing class SentryRetentionBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Sentry_Event__c
            WHERE Retain_Until__c < :System.today()
        ]);
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {
        if (!scope.isEmpty()) {
            Database.delete(scope, false);
        }
    }

    public void finish(Database.BatchableContext context) {
    }
}
