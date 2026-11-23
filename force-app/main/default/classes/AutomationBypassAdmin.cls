/**
 * Enables, disables and lists bypasses, and writes the audit log.
 *
 * Used by the Automation Bypass console (through BypassController) and by
 * anonymous Apex scripts in a migration or deployment pipeline, for example:
 *
 *   AutomationBypassAdmin.Scope scope = new AutomationBypassAdmin.Scope();
 *   scope.validationRules = true;
 *   scope.objects = 'Account,Contact';
 *   AutomationBypassAdmin.enable(migrationUserId, scope, 4, 'Wave 2 account load');
 *
 * Every bypass must expire, between 1 and MAX_HOURS hours from now.
 */
public with sharing class AutomationBypassAdmin {

    public static final Integer MAX_HOURS = 72;

    public class BypassException extends Exception {}

    /** What to bypass. */
    public class Scope {
        @AuraEnabled public Boolean all = false;
        @AuraEnabled public Boolean triggers = false;
        @AuraEnabled public Boolean flows = false;
        @AuraEnabled public Boolean validationRules = false;
        @AuraEnabled public String objects;
        @AuraEnabled public String handlers;

        public Boolean isEmpty() {
            return all != true && triggers != true && flows != true && validationRules != true
                && String.isBlank(objects) && String.isBlank(handlers);
        }

        public String describe() {
            List<String> parts = new List<String>();
            if (all == true) { parts.add('All automation'); }
            if (triggers == true) { parts.add('Triggers'); }
            if (flows == true) { parts.add('Flows'); }
            if (validationRules == true) { parts.add('Validation Rules'); }
            if (String.isNotBlank(objects)) { parts.add('Objects: ' + objects.trim()); }
            if (String.isNotBlank(handlers)) { parts.add('Handlers: ' + handlers.trim()); }
            return String.join(parts, '; ').left(255);
        }
    }

    /** A bypass as shown in the console. */
    public class BypassInfo {
        @AuraEnabled public Id id;
        @AuraEnabled public Id targetId;
        @AuraEnabled public String targetName;
        @AuraEnabled public String level;
        @AuraEnabled public String scope;
        @AuraEnabled public String reason;
        @AuraEnabled public Datetime expiresAt;
        @AuraEnabled public Boolean isExpired;
    }

    /**
     * Turn on a bypass for a user, a profile, or the whole org (pass the org Id).
     * Replaces any bypass that target already has.
     */
    public static Automation_Bypass__c enable(Id targetId, Scope scope, Integer hours, String reason) {
        if (targetId == null) {
            throw new BypassException('Choose who the bypass applies to.');
        }
        SObjectType targetType = targetId.getSObjectType();
        if (targetType != User.SObjectType && targetType != Profile.SObjectType && targetType != Organization.SObjectType) {
            throw new BypassException('A bypass can only apply to a user, a profile or the org.');
        }
        if (scope == null || scope.isEmpty()) {
            throw new BypassException('Choose at least one kind of automation to bypass.');
        }
        if (hours == null || hours < 1 || hours > MAX_HOURS) {
            throw new BypassException('The bypass must last between 1 and ' + MAX_HOURS + ' hours.');
        }
        if (String.isBlank(reason)) {
            throw new BypassException('Give a reason, such as the migration or release this bypass supports.');
        }

        Automation_Bypass__c setting = findForTarget(targetId);
        String action = setting == null ? 'Enabled' : 'Updated';
        if (setting == null) {
            setting = new Automation_Bypass__c(SetupOwnerId = targetId);
        }
        setting.Bypass_All__c = scope.all == true;
        setting.Bypass_Triggers__c = scope.triggers == true;
        setting.Bypass_Flows__c = scope.flows == true;
        setting.Bypass_Validation_Rules__c = scope.validationRules == true;
        setting.Bypassed_Objects__c = String.isBlank(scope.objects) ? null : scope.objects.trim().left(255);
        setting.Bypassed_Handlers__c = String.isBlank(scope.handlers) ? null : scope.handlers.trim().left(255);
        setting.Expires_At__c = Datetime.now().addHours(hours);
        setting.Reason__c = reason.trim().left(255);
        upsert setting;

        insert buildLog(action, targetId, targetName(targetId), scope.describe(), setting.Reason__c, setting.Expires_At__c, UserInfo.getUserId());
        return setting;
    }

    /** Turn off the bypass for a target. Returns false if it had none. */
    public static Boolean disable(Id targetId, String reason) {
        Automation_Bypass__c setting = findForTarget(targetId);
        if (setting == null) {
            return false;
        }
        Bypass_Log__c log = buildLog('Disabled', targetId, targetName(targetId), describe(setting),
            String.isBlank(reason) ? 'Disabled manually' : reason.trim().left(255), setting.Expires_At__c, UserInfo.getUserId());
        delete setting;
        insert log;
        return true;
    }

    /** Remove every expired bypass and log it. Returns how many were removed. */
    public static Integer expireOld() {
        List<Automation_Bypass__c> expired = [
            SELECT Id, SetupOwnerId, Bypass_All__c, Bypass_Triggers__c, Bypass_Flows__c, Bypass_Validation_Rules__c,
                   Bypassed_Objects__c, Bypassed_Handlers__c, Reason__c, Expires_At__c
            FROM Automation_Bypass__c
            WHERE Expires_At__c != null AND Expires_At__c <= :Datetime.now()
        ];
        if (expired.isEmpty()) {
            return 0;
        }
        Map<Id, String> names = targetNames(expired);
        List<Bypass_Log__c> logs = new List<Bypass_Log__c>();
        for (Automation_Bypass__c setting : expired) {
            logs.add(buildLog('Expired', setting.SetupOwnerId, names.get(setting.SetupOwnerId), describe(setting),
                setting.Reason__c, setting.Expires_At__c, null));
        }
        delete expired;
        insert logs;
        return expired.size();
    }

    /** Every bypass record, newest expiry first, for the console. */
    public static List<BypassInfo> listAll() {
        List<Automation_Bypass__c> settings = [
            SELECT Id, SetupOwnerId, Bypass_All__c, Bypass_Triggers__c, Bypass_Flows__c, Bypass_Validation_Rules__c,
                   Bypassed_Objects__c, Bypassed_Handlers__c, Reason__c, Expires_At__c
            FROM Automation_Bypass__c
            ORDER BY Expires_At__c DESC NULLS FIRST
        ];
        Map<Id, String> names = targetNames(settings);
        List<BypassInfo> result = new List<BypassInfo>();
        for (Automation_Bypass__c setting : settings) {
            BypassInfo info = new BypassInfo();
            info.id = setting.Id;
            info.targetId = setting.SetupOwnerId;
            info.targetName = names.get(setting.SetupOwnerId);
            info.level = levelOf(setting.SetupOwnerId);
            info.scope = describe(setting);
            info.reason = setting.Reason__c;
            info.expiresAt = setting.Expires_At__c;
            info.isExpired = setting.Expires_At__c != null && setting.Expires_At__c <= Datetime.now();
            result.add(info);
        }
        return result;
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    private static Automation_Bypass__c findForTarget(Id targetId) {
        List<Automation_Bypass__c> found = [
            SELECT Id, SetupOwnerId, Bypass_All__c, Bypass_Triggers__c, Bypass_Flows__c, Bypass_Validation_Rules__c,
                   Bypassed_Objects__c, Bypassed_Handlers__c, Reason__c, Expires_At__c
            FROM Automation_Bypass__c
            WHERE SetupOwnerId = :targetId
            LIMIT 1
        ];
        return found.isEmpty() ? null : found[0];
    }

    @TestVisible
    private static String describe(Automation_Bypass__c setting) {
        Scope scope = new Scope();
        scope.all = setting.Bypass_All__c;
        scope.triggers = setting.Bypass_Triggers__c;
        scope.flows = setting.Bypass_Flows__c;
        scope.validationRules = setting.Bypass_Validation_Rules__c;
        scope.objects = setting.Bypassed_Objects__c;
        scope.handlers = setting.Bypassed_Handlers__c;
        return scope.describe();
    }

    private static String levelOf(Id targetId) {
        SObjectType t = targetId.getSObjectType();
        if (t == User.SObjectType) { return 'User'; }
        if (t == Profile.SObjectType) { return 'Profile'; }
        return 'Org';
    }

    private static String targetName(Id targetId) {
        return targetNames(new List<Automation_Bypass__c>{ new Automation_Bypass__c(SetupOwnerId = targetId) }).get(targetId);
    }

    private static Map<Id, String> targetNames(List<Automation_Bypass__c> settings) {
        Set<Id> userIds = new Set<Id>();
        Set<Id> profileIds = new Set<Id>();
        Map<Id, String> names = new Map<Id, String>();
        for (Automation_Bypass__c setting : settings) {
            SObjectType t = setting.SetupOwnerId.getSObjectType();
            if (t == User.SObjectType) {
                userIds.add(setting.SetupOwnerId);
            } else if (t == Profile.SObjectType) {
                profileIds.add(setting.SetupOwnerId);
            } else {
                names.put(setting.SetupOwnerId, 'Entire org');
            }
        }
        if (!userIds.isEmpty()) {
            for (User u : [SELECT Id, Name, Username FROM User WHERE Id IN :userIds]) {
                names.put(u.Id, u.Name + ' (' + u.Username + ')');
            }
        }
        if (!profileIds.isEmpty()) {
            for (Profile p : [SELECT Id, Name FROM Profile WHERE Id IN :profileIds]) {
                names.put(p.Id, 'Profile: ' + p.Name);
            }
        }
        return names;
    }

    private static Bypass_Log__c buildLog(String action, Id targetId, String name, String scope, String reason, Datetime expiresAt, Id performedBy) {
        return new Bypass_Log__c(
            Action__c = action,
            Target_Id__c = targetId,
            Target_Name__c = name == null ? null : name.left(121),
            Scope__c = scope == null ? null : scope.left(255),
            Reason__c = reason == null ? null : reason.left(255),
            Expires_At__c = expiresAt,
            Performed_By__c = performedBy
        );
    }
}
