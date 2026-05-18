trigger SentryEventTrigger on Sentry_Event__e (after insert) {
    SentryEventIngestionService.handlePlatformEvents(Trigger.New);
}
