public with sharing class SentryElfRetrievalQueueable implements Queueable {
    private final Id jobId;
    private final List<String> eventTypes;
    private final Datetime startDateTime;
    private final Datetime endDateTime;

    public SentryElfRetrievalQueueable(Id jobId, List<String> eventTypes, Datetime startDateTime, Datetime endDateTime) {
        this.jobId = jobId;
        this.eventTypes = eventTypes;
        this.startDateTime = startDateTime;
        this.endDateTime = endDateTime;
    }

    public void execute(QueueableContext context) {
        SentryElfRetrievalService.harvest(jobId, new Set<String>(eventTypes), startDateTime, endDateTime);
    }
}
