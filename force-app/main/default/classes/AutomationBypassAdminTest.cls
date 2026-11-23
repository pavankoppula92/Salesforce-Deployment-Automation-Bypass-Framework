@IsTest
private class AutomationBypassAdminTest {

    private static AutomationBypassAdmin.Scope validationScope() {
        AutomationBypassAdmin.Scope scope = new AutomationBypassAdmin.Scope();
        scope.validationRules = true;
        scope.objects = 'Account';
        return scope;
    }

    private static void expectError(Id targetId, AutomationBypassAdmin.Scope scope, Integer hours, String reason, String fragment) {
        try {
            AutomationBypassAdmin.enable(targetId, scope, hours, reason);
            System.assert(false, 'Expected an error containing: ' + fragment);
        } catch (AutomationBypassAdmin.BypassException e) {
            System.assert(e.getMessage().contains(fragment), e.getMessage());
        }
    }

    @IsTest
    static void enableCreatesSettingAndLog() {
        Test.startTest();
        Automation_Bypass__c setting = AutomationBypassAdmin.enable(UserInfo.getUserId(), validationScope(), 4, 'Wave 1 load');
        Test.stopTest();

        System.assertEquals(true, setting.Bypass_Validation_Rules__c);
        System.assert(setting.Expires_At__c > Datetime.now().addHours(3));
        Bypass_Log__c log = [SELECT Action__c, Scope__c, Reason__c, Performed_By__c FROM Bypass_Log__c];
        System.assertEquals('Enabled', log.Action__c);
        System.assertEquals('Validation Rules; Objects: Account', log.Scope__c);
        System.assertEquals(UserInfo.getUserId(), log.Performed_By__c);
        System.assertEquals(true, AutomationBypass.isValidationBypassed());
    }

    @IsTest
    static void enablingAgainUpdatesTheSameSetting() {
        AutomationBypassAdmin.enable(UserInfo.getUserId(), validationScope(), 2, 'First');
        AutomationBypassAdmin.Scope scope = new AutomationBypassAdmin.Scope();
        scope.triggers = true;
        AutomationBypassAdmin.enable(UserInfo.getUserId(), scope, 2, 'Second');

        List<Automation_Bypass__c> settings = [SELECT Bypass_Triggers__c, Bypass_Validation_Rules__c, Reason__c FROM Automation_Bypass__c];
        System.assertEquals(1, settings.size());
        System.assertEquals(true, settings[0].Bypass_Triggers__c);
        System.assertEquals(false, settings[0].Bypass_Validation_Rules__c);
        System.assertEquals('Second', settings[0].Reason__c);
        System.assertEquals(1, [SELECT COUNT() FROM Bypass_Log__c WHERE Action__c = 'Updated']);
    }

    @IsTest
    static void rejectsBadInput() {
        Id userId = UserInfo.getUserId();
        expectError(null, validationScope(), 4, 'Reason', 'Choose who');
        expectError(Id.valueOf('001000000000000AAA'), validationScope(), 4, 'Reason', 'user, a profile or the org');
        expectError(userId, new AutomationBypassAdmin.Scope(), 4, 'Reason', 'at least one');
        expectError(userId, null, 4, 'Reason', 'at least one');
        expectError(userId, validationScope(), 0, 'Reason', 'between 1 and');
        expectError(userId, validationScope(), AutomationBypassAdmin.MAX_HOURS + 1, 'Reason', 'between 1 and');
        expectError(userId, validationScope(), null, 'Reason', 'between 1 and');
        expectError(userId, validationScope(), 4, '  ', 'reason');
        System.assertEquals(0, [SELECT COUNT() FROM Automation_Bypass__c]);
    }

    @IsTest
    static void disableRemovesSettingAndLogs() {
        AutomationBypassAdmin.enable(UserInfo.getUserId(), validationScope(), 4, 'Load');
        System.assertEquals(true, AutomationBypassAdmin.disable(UserInfo.getUserId(), null));
        System.assertEquals(0, [SELECT COUNT() FROM Automation_Bypass__c]);
        Bypass_Log__c log = [SELECT Reason__c FROM Bypass_Log__c WHERE Action__c = 'Disabled'];
        System.assertEquals('Disabled manually', log.Reason__c);
        System.assertEquals(false, AutomationBypassAdmin.disable(UserInfo.getUserId(), 'Again'));
    }

    @IsTest
    static void expireOldRemovesOnlyExpired() {
        insert new Automation_Bypass__c(SetupOwnerId = UserInfo.getUserId(), Bypass_Flows__c = true,
            Expires_At__c = Datetime.now().addMinutes(-5), Reason__c = 'Old load');
        insert new Automation_Bypass__c(SetupOwnerId = UserInfo.getProfileId(), Bypass_Triggers__c = true,
            Expires_At__c = Datetime.now().addHours(2), Reason__c = 'Current load');

        System.assertEquals(1, AutomationBypassAdmin.expireOld());
        System.assertEquals(1, [SELECT COUNT() FROM Automation_Bypass__c]);
        Bypass_Log__c log = [SELECT Action__c, Performed_By__c, Target_Id__c FROM Bypass_Log__c];
        System.assertEquals('Expired', log.Action__c);
        System.assertEquals(null, log.Performed_By__c);
        System.assertEquals(0, AutomationBypassAdmin.expireOld());
    }

    @IsTest
    static void listAllCoversUserProfileAndOrg() {
        AutomationBypassAdmin.Scope all = new AutomationBypassAdmin.Scope();
        all.all = true;
        all.handlers = 'AccountTriggerHandler';
        AutomationBypassAdmin.enable(UserInfo.getUserId(), all, 1, 'User level');
        AutomationBypassAdmin.enable(UserInfo.getProfileId(), validationScope(), 1, 'Profile level');
        AutomationBypassAdmin.enable(UserInfo.getOrganizationId(), validationScope(), 1, 'Org level');

        Map<String, AutomationBypassAdmin.BypassInfo> byLevel = new Map<String, AutomationBypassAdmin.BypassInfo>();
        for (AutomationBypassAdmin.BypassInfo info : AutomationBypassAdmin.listAll()) {
            byLevel.put(info.level, info);
        }
        System.assertEquals(new Set<String>{ 'User', 'Profile', 'Org' }, byLevel.keySet());
        System.assertEquals('Entire org', byLevel.get('Org').targetName);
        System.assert(byLevel.get('Profile').targetName.startsWith('Profile: '));
        System.assert(byLevel.get('User').scope.contains('All automation'));
        System.assert(byLevel.get('User').scope.contains('Handlers: AccountTriggerHandler'));
        System.assertEquals(false, byLevel.get('User').isExpired);
    }
}
