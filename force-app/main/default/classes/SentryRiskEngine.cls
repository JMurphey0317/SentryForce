public with sharing class SentryRiskEngine {
    public class Result {
        public Integer score = 0;
        public String alertType = 'Generic';
        public List<String> matchedRules = new List<String>();

        public void add(Integer points, String ruleName, String resolvedAlertType) {
            score += points;
            matchedRules.add(ruleName);
            if (alertType == 'Generic' && String.isNotBlank(resolvedAlertType)) {
                alertType = resolvedAlertType;
            }
        }

        public String summary() {
            return matchedRules.isEmpty() ? 'No anomaly rules matched.' : String.join(matchedRules, '; ');
        }

        public Boolean shouldAlert(SentrySettings.Configuration settings) {
            return settings.enableAlerts && score >= settings.alertRiskScoreThreshold;
        }
    }

    public static Result evaluate(SentryEventIngestionService.SentryEventRequest request, SentrySettings.Configuration settings) {
        Result result = new Result();
        Map<String, Object> payload = parsePayload(request.payloadJson);
        String eventType = String.isBlank(request.eventType) ? '' : request.eventType.toLowerCase();
        String sourceType = String.isBlank(request.sourceType) ? '' : request.sourceType;
        Integer loginFailures = getInteger(payload, 'loginFailureCount');
        Integer bulkDownloadCount = getInteger(payload, 'bulkDownloadCount');
        Boolean sessionHijackIndicator = getBoolean(payload, 'sessionHijackIndicator') || getBoolean(payload, 'ipMismatch');
        Boolean exportEvent = eventType.contains('export') || eventType.contains('download') || eventType.contains('report');
        Boolean offHours = isOffHours(request.occurredOn, settings);
        Long durationMs = request.durationMs == null ? 0 : request.durationMs;

        if (
            loginFailures >= settings.loginFailureThreshold &&
            (eventType.contains('login') || eventType.contains('authentication') || payload.containsKey('loginFailureCount') || payload.containsKey('failedLogins'))
        ) {
            result.add(60, 'Credential stuffing threshold exceeded', 'Credential Stuffing');
        }
        if (sessionHijackIndicator) {
            result.add(70, 'Session hijack indicator detected', 'Session Hijack');
        }
        if (exportEvent && bulkDownloadCount >= settings.bulkDownloadThreshold) {
            result.add(55, 'Bulk export/download threshold exceeded', 'Suspicious Export');
        }
        if (exportEvent && offHours) {
            result.add(20, 'Off-hours export or report access detected', 'Suspicious Export');
        }
        if (sourceType == 'Lightning' && durationMs >= settings.pagePerformanceThresholdMs) {
            result.add(30, 'Lightning page load exceeded threshold', 'Lightning Performance');
        }
        if (sourceType == 'Apex' && durationMs >= settings.apexPerformanceThresholdMs) {
            result.add(35, 'Apex execution exceeded threshold', 'Apex Performance');
        }
        if (String.isNotBlank(request.stackTrace)) {
            result.add(40, 'Unhandled exception captured', 'Apex Exception');
        }
        if ('Error'.equalsIgnoreCase(request.severity) || 'Critical'.equalsIgnoreCase(request.severity)) {
            result.add(10, 'High severity event recorded', result.alertType);
        }
        if ('Event Monitoring'.equals(sourceType) && settings.enableEventMonitoring) {
            result.add(5, 'Event Monitoring telemetry retained for audit', result.alertType);
        }
        result.score = Math.min(result.score, 100);
        return result;
    }

    private static Map<String, Object> parsePayload(String payloadJson) {
        if (String.isBlank(payloadJson)) {
            return new Map<String, Object>();
        }
        Object raw = JSON.deserializeUntyped(payloadJson);
        return raw instanceof Map<String, Object> ? (Map<String, Object>) raw : new Map<String, Object>();
    }

    private static Integer getInteger(Map<String, Object> payload, String key) {
        if (!payload.containsKey(key) || payload.get(key) == null) {
            return 0;
        }
        Object rawValue = payload.get(key);
        if (rawValue instanceof Integer) {
            return (Integer) rawValue;
        }
        if (rawValue instanceof Long) {
            return Integer.valueOf(String.valueOf(rawValue));
        }
        if (rawValue instanceof Decimal) {
            return ((Decimal) rawValue).intValue();
        }
        return Integer.valueOf(String.valueOf(rawValue));
    }

    private static Boolean getBoolean(Map<String, Object> payload, String key) {
        if (!payload.containsKey(key) || payload.get(key) == null) {
            return false;
        }
        Object rawValue = payload.get(key);
        if (rawValue instanceof Boolean) {
            return (Boolean) rawValue;
        }
        return 'true'.equalsIgnoreCase(String.valueOf(rawValue));
    }

    private static Boolean isOffHours(Datetime occurredOn, SentrySettings.Configuration settings) {
        Datetime comparisonTime = occurredOn == null ? System.now() : occurredOn;
        Time currentTime = Time.newInstance(comparisonTime.hour(), comparisonTime.minute(), 0, 0);
        Time startTime = SentrySettings.parseTime(settings.offHoursStart, Time.newInstance(22, 0, 0, 0));
        Time endTime = SentrySettings.parseTime(settings.offHoursEnd, Time.newInstance(6, 0, 0, 0));
        if (startTime == endTime) {
            return false;
        }
        if (startTime > endTime) {
            return currentTime >= startTime || currentTime < endTime;
        }
        return currentTime >= startTime && currentTime < endTime;
    }
}
