@IsTest
private class SentryEventIngestionService_Tests {
    @IsTest
    static void persistsEventsAndCreatesAlerts() {
        SentrySettings.Configuration configuration = new SentrySettings.Configuration();
        configuration.alertRiskScoreThreshold = 60;
        configuration.apexPerformanceThresholdMs = 1000;
        SentrySettings.setMock(configuration);

        SentryEventIngestionService.SentryEventRequest request = new SentryEventIngestionService.SentryEventRequest();
        request.context = 'UnitTest';
        request.durationMs = 5000L;
        request.eventType = 'UnhandledException';
        request.message = 'Unit test failure';
        request.occurredOn = System.now();
        request.payloadJson = JSON.serialize(new Map<String, Object>{ 'recordsProcessed' => 25 });
        request.severity = 'Error';
        request.sourceChannel = 'Apex';
        request.sourceType = 'Apex';
        request.stackTrace = 'Class.UnitTest: line 12';
        request.transactionId = 'txn-001';
        request.userId = UserInfo.getUserId();

        Test.startTest();
        List<Sentry_Event__c> events = SentryEventIngestionService.persist(new List<SentryEventIngestionService.SentryEventRequest>{ request });
        Test.stopTest();

        System.assertEquals(1, events.size());
        Sentry_Event__c storedEvent = [SELECT Alert_Status__c, Risk_Score__c, Source_Type__c, Stack_Trace__c FROM Sentry_Event__c LIMIT 1];
        System.assertEquals('Open', storedEvent.Alert_Status__c);
        System.assertEquals('Apex', storedEvent.Source_Type__c);
        System.assert(String.isNotBlank(storedEvent.Stack_Trace__c));
        System.assert(storedEvent.Risk_Score__c >= 60);

        Sentry_Alert__c alertRecord = [SELECT Alert_Type__c, Severity__c, Status__c FROM Sentry_Alert__c LIMIT 1];
        System.assertEquals('Open', alertRecord.Status__c);
        System.assertEquals('High', alertRecord.Severity__c);
    }

    @IsTest
    static void mapsPlatformEventFields() {
        Sentry_Event__e platformEvent = new Sentry_Event__e(
            Context__c = 'Platform',
            Duration_Ms__c = 123,
            Event_Key__c = 'evt-1',
            Event_Type__c = 'Order_Status_Changed__e',
            Message__c = 'Status changed',
            Occurred_On__c = System.now(),
            Payload__c = '{"state":"Closed Won"}',
            Record_Id__c = '001000000000001AAA',
            Retrieval_Job_Id__c = 'a01000000000001AAA',
            Severity__c = 'Info',
            Source_Channel__c = 'Platform Event',
            Source_Type__c = 'Platform Event',
            Stack_Trace__c = null,
            Transaction_Id__c = 'txn-2',
            User_Id__c = UserInfo.getUserId()
        );

        SentryEventIngestionService.SentryEventRequest request = SentryEventIngestionService.SentryEventRequest.fromPlatformEvent(platformEvent);
        System.assertEquals('Platform', request.context);
        System.assertEquals('Order_Status_Changed__e', request.eventType);
        System.assertEquals('Platform Event', request.sourceType);
        System.assertEquals('evt-1', request.eventKey);
    }
}
