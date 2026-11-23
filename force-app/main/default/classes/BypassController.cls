/**
 * Apex controller for the bypassConsole Lightning Web Component.
 * Every method requires the Manage_Automation_Bypass custom permission.
 */
public with sharing class BypassController {

    public static final String PERMISSION = 'Manage_Automation_Bypass';

    @TestVisible
    private static Boolean permissionOverride;

    @AuraEnabled
    public static List<AutomationBypassAdmin.BypassInfo> getBypasses() {
        requirePermission();
        return AutomationBypassAdmin.listAll();
    }

    @AuraEnabled
    public static void enableBypass(Id targetId, Boolean bypassAll, Boolean triggers, Boolean flows,
                                    Boolean validationRules, String objects, String handlers,
                                    Integer hours, String reason) {
        requirePermission();
        AutomationBypassAdmin.Scope scope = new AutomationBypassAdmin.Scope();
        scope.all = bypassAll == true;
        scope.triggers = triggers == true;
        scope.flows = flows == true;
        scope.validationRules = validationRules == true;
        scope.objects = objects;
        scope.handlers = handlers;
        try {
            AutomationBypassAdmin.enable(targetId, scope, hours, reason);
        } catch (AutomationBypassAdmin.BypassException e) {
            throw auraError(e.getMessage());
        }
    }

    @AuraEnabled
    public static void disableBypass(Id targetId, String reason) {
        requirePermission();
        AutomationBypassAdmin.disable(targetId, reason);
    }

    @AuraEnabled
    public static Id getOrgId() {
        requirePermission();
        return UserInfo.getOrganizationId();
    }

    private static void requirePermission() {
        Boolean allowed = permissionOverride != null ? permissionOverride : FeatureManagement.checkPermission(PERMISSION);
        if (!allowed) {
            throw auraError('You need the Manage Automation Bypass permission to do this.');
        }
    }

    private static AuraHandledException auraError(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}
