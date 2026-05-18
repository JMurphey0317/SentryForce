@IsTest
private class SentryRiskEngine_Tests {
    @IsTest
    static void scoresCredentialStuffingAndExports() {
        SentrySettings.Configuration configuration = new SentrySettings.Configuration();
        configuration.loginFailureThreshold = 5;
        configuration.bulkDownloadThreshold = 100;
        configuration.alertRiskScoreThreshold = 70;
        configuration.offHoursStart = '22:00';
        configuration.offHoursEnd = '06:00';
        SentrySettings.setMock(configuration);

        SentryEventIngestionService.SentryEventRequest request = new SentryEventIngestionService.SentryEventRequest();
        request.eventType = 'ReportExport';
        request.message = 'Night export detected';
        request.occurredOn = Datetime.newInstance(2026, 1, 1, 2, 30, 0);
        request.payloadJson = JSON.serialize(new Map<String, Object>{
            'loginFailureCount' => 6,
            'bulkDownloadCount' => 250,
            'ipMismatch' => true
        });
        request.severity = 'Error';
        request.sourceType = 'Event Monitoring';

        SentryRiskEngine.Result result = SentryRiskEngine.evaluate(request, configuration);
        System.assert(result.score >= 90, 'Expected high score for suspicious activity.');
        System.assert(result.summary().contains('Credential stuffing'));
        System.assert(result.summary().contains('Session hijack'));
        System.assert(result.summary().contains('Off-hours export'));
    }

    @IsTest
    static void scoresPerformanceSignals() {
        SentrySettings.Configuration configuration = new SentrySettings.Configuration();
        configuration.pagePerformanceThresholdMs = 1500;
        configuration.apexPerformanceThresholdMs = 2000;
        SentrySettings.setMock(configuration);

        SentryEventIngestionService.SentryEventRequest lightningRequest = new SentryEventIngestionService.SentryEventRequest();
        lightningRequest.sourceType = 'Lightning';
        lightningRequest.durationMs = 2000L;
        lightningRequest.severity = 'Warn';
        lightningRequest.occurredOn = System.now();
        SentryRiskEngine.Result lightningResult = SentryRiskEngine.evaluate(lightningRequest, configuration);
        System.assertEquals('Lightning Performance', lightningResult.alertType);
        System.assert(lightningResult.score > 0);

        SentryEventIngestionService.SentryEventRequest apexRequest = new SentryEventIngestionService.SentryEventRequest();
        apexRequest.sourceType = 'Apex';
        apexRequest.durationMs = 2500L;
        apexRequest.stackTrace = 'Example stack';
        apexRequest.severity = 'Error';
        apexRequest.occurredOn = System.now();
        SentryRiskEngine.Result apexResult = SentryRiskEngine.evaluate(apexRequest, configuration);
        System.assert(apexResult.score > lightningResult.score);
    }
}
