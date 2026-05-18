@IsTest
private class SentryRetentionService_Tests {
    @IsTest
    static void purgesOnlyExpiredEvents() {
        insert new List<Sentry_Event__c>{
            new Sentry_Event__c(
                Alert_Status__c = 'None',
                Context__c = 'Expired',
                Event_Key__c = 'old-1',
                Event_Type__c = 'ExpiredEvent',
                Message__c = 'Old',
                Occurred_On__c = System.now().addDays(-30),
                Retain_Until__c = System.today().addDays(-1),
                Risk_Score__c = 10,
                Severity__c = 'Info',
                Source_Channel__c = 'Apex',
                Source_Type__c = 'Application',
                Transaction_Id__c = 'old'
            ),
            new Sentry_Event__c(
                Alert_Status__c = 'None',
                Context__c = 'Active',
                Event_Key__c = 'new-1',
                Event_Type__c = 'ActiveEvent',
                Message__c = 'New',
                Occurred_On__c = System.now(),
                Retain_Until__c = System.today().addDays(10),
                Risk_Score__c = 5,
                Severity__c = 'Info',
                Source_Channel__c = 'Apex',
                Source_Type__c = 'Application',
                Transaction_Id__c = 'new'
            )
        };

        Test.startTest();
        Integer purgedCount = SentryRetentionService.purgeExpiredEvents(50);
        Test.stopTest();

        System.assertEquals(1, purgedCount);
        System.assertEquals(1, [SELECT COUNT() FROM Sentry_Event__c]);
        System.assertEquals('new-1', [SELECT Event_Key__c FROM Sentry_Event__c LIMIT 1].Event_Key__c);
    }
}
