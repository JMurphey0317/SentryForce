@IsTest
private class SentryElfRetrievalService_Tests {
    @IsTest
    static void updatesRetrievalJobAndCreatesEvents() {
        SentrySettings.Configuration configuration = new SentrySettings.Configuration();
        configuration.enableEventMonitoring = true;
        SentrySettings.setMock(configuration);
        SentryElfRetrievalService.setMockEventLogFiles(new List<Map<String, Object>>{
            new Map<String, Object>{
                'Id' => '0AT000000000001AAA',
                'EventType' => 'Login',
                'LogDate' => Date.today(),
                'Interval' => 'Hourly',
                'LogFileLength' => 12345,
                'Sequence' => 1
            }
        });

        Sentry_Retrieval_Job__c job = new Sentry_Retrieval_Job__c(
            Event_Types__c = 'Login',
            Requested_Start__c = System.now().addDays(-1),
            Requested_End__c = System.now(),
            Status__c = 'Queued'
        );
        insert job;

        Test.startTest();
        Integer matches = SentryElfRetrievalService.harvest(job.Id, new Set<String>{ 'Login' }, System.now().addDays(-1), System.now());
        Test.stopTest();

        job = [SELECT Status__c, Matched_Log_Count__c, Error_Message__c FROM Sentry_Retrieval_Job__c WHERE Id = :job.Id];
        System.assertEquals(1, matches);
        System.assertEquals('Completed', job.Status__c);
        System.assertEquals(1, Integer.valueOf(String.valueOf(job.Matched_Log_Count__c)));
        System.assertEquals(null, job.Error_Message__c);
        System.assertEquals(1, [SELECT COUNT() FROM Sentry_Event__c WHERE Retrieval_Job__c = :job.Id]);
    }
}
