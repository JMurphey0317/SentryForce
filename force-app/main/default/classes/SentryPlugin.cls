public without sharing class SentryPlugin {
    private static final Map<String, Sentry_Plugin__mdt> DEVELOPER_NAME_TO_RECORD = loadEnabledRecords();

    public interface Batchable {
        void start(Sentry_Plugin__mdt configuration, Map<String, Object> context);
        void execute(Sentry_Plugin__mdt configuration, Map<String, Object> context, List<SObject> scopeRecords);
        void finish(Sentry_Plugin__mdt configuration, Map<String, Object> context);
    }

    public interface Triggerable {
        void execute(Sentry_Plugin__mdt configuration, List<Sentry_Event__c> events, List<Sentry_Alert__c> alerts);
    }

    public static List<Sentry_Plugin__mdt> getPluginConfigurations() {
        return DEVELOPER_NAME_TO_RECORD.values();
    }

    public static Batchable newBatchableInstance(String apexClassTypeName) {
        Object pluginInstance = newPluginInstance(apexClassTypeName);
        return pluginInstance instanceof Batchable ? (Batchable) pluginInstance : null;
    }

    public static Triggerable newTriggerableInstance(String apexClassTypeName) {
        Object pluginInstance = newPluginInstance(apexClassTypeName);
        return pluginInstance instanceof Triggerable ? (Triggerable) pluginInstance : null;
    }

    @TestVisible
    private static void setMock(Sentry_Plugin__mdt pluginConfiguration) {
        if (String.isBlank(pluginConfiguration.DeveloperName)) {
            throw new System.IllegalArgumentException('DeveloperName is required on mock plugin configuration.');
        }
        if (pluginConfiguration.Is_Enabled__c) {
            DEVELOPER_NAME_TO_RECORD.put(pluginConfiguration.DeveloperName, pluginConfiguration);
        }
    }

    private static Object newPluginInstance(String apexClassTypeName) {
        return String.isBlank(apexClassTypeName) ? null : System.Type.forName(apexClassTypeName)?.newInstance();
    }

    private static Map<String, Sentry_Plugin__mdt> loadEnabledRecords() {
        Map<String, Sentry_Plugin__mdt> configurations = new Map<String, Sentry_Plugin__mdt>();
        if (Test.isRunningTest()) {
            return configurations;
        }
        for (Sentry_Plugin__mdt configuration : [
            SELECT DeveloperName, Apex_Class__c, Event_Source__c, Is_Enabled__c
            FROM Sentry_Plugin__mdt
            WHERE Is_Enabled__c = true
        ]) {
            configurations.put(configuration.DeveloperName, configuration);
        }
        return configurations;
    }
}
