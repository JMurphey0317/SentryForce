public with sharing class SentryRetentionScheduler implements Schedulable {
    public void execute(SchedulableContext context) {
        Database.executeBatch(new SentryRetentionBatch(), 200);
    }
}
