/**
 * Central answer to "should this automation run right now?".
 *
 * Two layers are checked:
 *  1. Runtime bypasses set in Apex for the current transaction only
 *     (for example a data fix script that must not fire one handler).
 *  2. The Automation_Bypass__c hierarchy custom setting for the running user,
 *     their profile or the org, which expires at Expires_At__c.
 *
 * Triggers call isTriggerBypassed (through TriggerHandler), Flows call
 * isFlowBypassed (through BypassFlowCheck or $Setup in a formula), and
 * validation rules read the custom setting directly in their formula.
 */
public with sharing class AutomationBypass {

    private static Boolean runtimeBypassAll = false;
    private static final Set<String> RUNTIME_HANDLERS = new Set<String>();
    private static final Set<String> RUNTIME_OBJECTS = new Set<String>();

    /** Lets tests supply a setting without DML. */
    @TestVisible
    private static Automation_Bypass__c settingOverride;

    // ------------------------------------------------------------------
    // Transaction-scoped bypasses
    // ------------------------------------------------------------------

    /** Bypass every framework-aware trigger and Flow for the rest of this transaction. */
    public static void bypassAll() {
        runtimeBypassAll = true;
    }

    /** Bypass one trigger handler class for the rest of this transaction. */
    public static void bypassHandler(String handlerName) {
        RUNTIME_HANDLERS.add(normalize(handlerName));
    }

    /** Bypass triggers and Flows on one object for the rest of this transaction. */
    public static void bypassObject(SObjectType objectType) {
        RUNTIME_OBJECTS.add(normalize(String.valueOf(objectType)));
    }

    public static void clearHandler(String handlerName) {
        RUNTIME_HANDLERS.remove(normalize(handlerName));
    }

    public static void clearObject(SObjectType objectType) {
        RUNTIME_OBJECTS.remove(normalize(String.valueOf(objectType)));
    }

    /** Remove every transaction-scoped bypass. The custom setting is not touched. */
    public static void clearRuntime() {
        runtimeBypassAll = false;
        RUNTIME_HANDLERS.clear();
        RUNTIME_OBJECTS.clear();
    }

    // ------------------------------------------------------------------
    // Checks
    // ------------------------------------------------------------------

    public static Boolean isTriggerBypassed(String handlerName, SObjectType objectType) {
        String handler = normalize(handlerName);
        String objectName = objectType == null ? null : normalize(String.valueOf(objectType));

        if (runtimeBypassAll || RUNTIME_HANDLERS.contains(handler) || (objectName != null && RUNTIME_OBJECTS.contains(objectName))) {
            return true;
        }

        Automation_Bypass__c setting = activeSetting();
        if (setting == null) {
            return false;
        }
        return setting.Bypass_All__c == true
            || setting.Bypass_Triggers__c == true
            || (objectName != null && parseList(setting.Bypassed_Objects__c).contains(objectName))
            || (handler != null && parseList(setting.Bypassed_Handlers__c).contains(handler));
    }

    /** objectApiName may be blank for Flows that are not tied to one object. */
    public static Boolean isFlowBypassed(String objectApiName) {
        String objectName = normalize(objectApiName);
        if (runtimeBypassAll || (objectName != null && RUNTIME_OBJECTS.contains(objectName))) {
            return true;
        }
        Automation_Bypass__c setting = activeSetting();
        if (setting == null) {
            return false;
        }
        return setting.Bypass_All__c == true
            || setting.Bypass_Flows__c == true
            || (objectName != null && parseList(setting.Bypassed_Objects__c).contains(objectName));
    }

    /** For Apex validation that should follow the same switch as declarative validation rules. */
    public static Boolean isValidationBypassed() {
        if (runtimeBypassAll) {
            return true;
        }
        Automation_Bypass__c setting = activeSetting();
        return setting != null && (setting.Bypass_All__c == true || setting.Bypass_Validation_Rules__c == true);
    }

    /**
     * The custom setting that applies to the running user (user, then profile,
     * then org default), or null when there is none or it has expired.
     */
    public static Automation_Bypass__c activeSetting() {
        Automation_Bypass__c setting = settingOverride != null ? settingOverride : Automation_Bypass__c.getInstance();
        if (setting == null) {
            return null;
        }
        if (setting.Expires_At__c != null && setting.Expires_At__c <= Datetime.now()) {
            return null;
        }
        return setting;
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    @TestVisible
    private static Set<String> parseList(String value) {
        Set<String> result = new Set<String>();
        if (String.isBlank(value)) {
            return result;
        }
        for (String part : value.split('[,;\\s]+')) {
            String cleaned = normalize(part);
            if (cleaned != null) {
                result.add(cleaned);
            }
        }
        return result;
    }

    @TestVisible
    private static String normalize(String value) {
        return String.isBlank(value) ? null : value.trim().toLowerCase();
    }
}
