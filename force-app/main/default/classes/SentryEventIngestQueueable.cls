public with sharing class SentryEventIngestQueueable implements Queueable {
    private final List<SentryEventIngestionService.SentryEventRequest> requests;

    public SentryEventIngestQueueable(List<SentryEventIngestionService.SentryEventRequest> requests) {
        this.requests = requests;
    }

    public void execute(QueueableContext context) {
        SentryEventIngestionService.persist(requests);
    }
}
