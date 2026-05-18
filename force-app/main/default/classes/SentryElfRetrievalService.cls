public with sharing class SentryElfRetrievalService {
    @TestVisible
    private static List<Map<String, Object>> mockEventLogFiles;

    public static Id queueRetrieval(Set<String> eventTypes, Datetime startDateTime, Datetime endDateTime) {
        Sentry_Retrieval_Job__c job = new Sentry_Retrieval_Job__c(
            Event_Types__c = eventTypes == null ? null : String.join(new List<String>(eventTypes), ', '),
            Requested_End__c = endDateTime,
            Requested_Start__c = startDateTime,
            Status__c = 'Queued'
        );
        insert job;
        System.enqueueJob(new SentryElfRetrievalQueueable(job.Id, eventTypes == null ? new List<String>() : new List<String>(eventTypes), startDateTime, endDateTime));
        return job.Id;
    }

    public static Integer harvest(Id jobId, Set<String> eventTypes, Datetime startDateTime, Datetime endDateTime) {
        Sentry_Retrieval_Job__c job = [
            SELECT Id, Status__c
            FROM Sentry_Retrieval_Job__c
            WHERE Id = :jobId
            LIMIT 1
        ];
        job.Status__c = 'In Progress';
        update job;

        try {
            List<Map<String, Object>> logFiles = queryEventLogFiles(eventTypes, startDateTime, endDateTime);
            List<SentryEventIngestionService.SentryEventRequest> requests = new List<SentryEventIngestionService.SentryEventRequest>();
            for (Map<String, Object> logFile : logFiles) {
                requests.add(toEventRequest(logFile, jobId));
            }
            if (!requests.isEmpty()) {
                SentryEventIngestionService.persist(requests);
            }
            job.Completed_On__c = System.now();
            job.Matched_Log_Count__c = requests.size();
            job.Status__c = 'Completed';
            job.Error_Message__c = null;
            update job;
            return requests.size();
        } catch (Exception ex) {
            job.Completed_On__c = System.now();
            job.Error_Message__c = ex.getMessage();
            job.Status__c = 'Failed';
            update job;
            return 0;
        }
    }

    @TestVisible
    static void setMockEventLogFiles(List<Map<String, Object>> mockedLogFiles) {
        mockEventLogFiles = mockedLogFiles;
    }

    private static List<Map<String, Object>> queryEventLogFiles(Set<String> eventTypes, Datetime startDateTime, Datetime endDateTime) {
        if (Test.isRunningTest() && mockEventLogFiles != null) {
            return mockEventLogFiles;
        }
        Date startDate = startDateTime == null ? null : startDateTime.date();
        Date endDate = endDateTime == null ? null : endDateTime.date();
        String query = 'SELECT Id, EventType, LogDate, Interval, LogFileLength, Sequence FROM EventLogFile';
        List<String> clauses = new List<String>();
        if (startDate != null) {
            clauses.add('LogDate >= :startDate');
        }
        if (endDate != null) {
            clauses.add('LogDate <= :endDate');
        }
        if (eventTypes != null && !eventTypes.isEmpty()) {
            clauses.add('EventType IN :eventTypes');
        }
        if (!clauses.isEmpty()) {
            query += ' WHERE ' + String.join(clauses, ' AND ');
        }
        query += ' ORDER BY LogDate DESC LIMIT 200';
        List<Map<String, Object>> logFiles = new List<Map<String, Object>>();
        for (SObject record : Database.query(query)) {
            logFiles.add(new Map<String, Object>{
                'Id' => record.get('Id'),
                'EventType' => record.get('EventType'),
                'LogDate' => record.get('LogDate'),
                'Interval' => record.get('Interval'),
                'LogFileLength' => record.get('LogFileLength'),
                'Sequence' => record.get('Sequence')
            });
        }
        return logFiles;
    }

    private static SentryEventIngestionService.SentryEventRequest toEventRequest(Map<String, Object> logFile, Id jobId) {
        SentryEventIngestionService.SentryEventRequest request = new SentryEventIngestionService.SentryEventRequest();
        request.context = 'EventLogFile';
        request.eventKey = String.valueOf(logFile.get('Id'));
        request.eventType = String.valueOf(logFile.get('EventType'));
        request.message = 'Event Monitoring log file discovered for retention and analysis';
        request.occurredOn = normalizeDate(logFile.get('LogDate'));
        request.payloadJson = JSON.serialize(logFile);
        request.retrievalJobId = String.valueOf(jobId);
        request.severity = 'Info';
        request.sourceChannel = 'ELF';
        request.sourceType = 'Event Monitoring';
        request.transactionId = Limits.getTransactionId();
        request.userId = UserInfo.getUserId();
        return request;
    }

    private static Datetime normalizeDate(Object rawDate) {
        if (rawDate instanceof Datetime) {
            return (Datetime) rawDate;
        }
        if (rawDate instanceof Date) {
            Date value = (Date) rawDate;
            return Datetime.newInstance(value, Time.newInstance(0, 0, 0, 0));
        }
        return System.now();
    }
}
