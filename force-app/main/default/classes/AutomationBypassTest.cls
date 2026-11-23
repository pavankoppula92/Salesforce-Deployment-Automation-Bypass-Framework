@IsTest
private class AutomationBypassTest {

    @IsTest
    static void noSettingMeansNothingIsBypassed() {
        System.assertEquals(false, AutomationBypass.isTriggerBypassed('AnyHandler', Account.SObjectType));
        System.assertEquals(false, AutomationBypass.isFlowBypassed('Account'));
        System.assertEquals(false, AutomationBypass.isValidationBypassed());
    }

    @IsTest
    static void userLevelSettingIsReadFromTheHierarchy() {
        insert new Automation_Bypass__c(
            SetupOwnerId = UserInfo.getUserId(),
            Bypass_Triggers__c = true,
            Expires_At__c = Datetime.now().addHours(1)
        );
        System.assertEquals(true, AutomationBypass.isTriggerBypassed('AnyHandler', Account.SObjectType));
        System.assertEquals(false, AutomationBypass.isFlowBypassed('Account'), 'Only triggers were bypassed');
    }

    @IsTest
    static void expiredSettingIsIgnored() {
        AutomationBypass.settingOverride = new Automation_Bypass__c(
            Bypass_All__c = true,
            Expires_At__c = Datetime.now().addMinutes(-1)
        );
        System.assertEquals(null, AutomationBypass.activeSetting());
        System.assertEquals(false, AutomationBypass.isTriggerBypassed('AnyHandler', Account.SObjectType));
        System.assertEquals(false, AutomationBypass.isValidationBypassed());
    }

    @IsTest
    static void bypassAllCoversEverything() {
        AutomationBypass.settingOverride = new Automation_Bypass__c(Bypass_All__c = true, Expires_At__c = Datetime.now().addHours(1));
        System.assertEquals(true, AutomationBypass.isTriggerBypassed('AnyHandler', Contact.SObjectType));
        System.assertEquals(true, AutomationBypass.isFlowBypassed(null));
        System.assertEquals(true, AutomationBypass.isValidationBypassed());
    }

    @IsTest
    static void objectListMatchesCaseInsensitively() {
        AutomationBypass.settingOverride = new Automation_Bypass__c(
            Bypassed_Objects__c = ' account ; Contact,Loan__c',
            Expires_At__c = Datetime.now().addHours(1)
        );
        System.assertEquals(true, AutomationBypass.isTriggerBypassed('AnyHandler', Account.SObjectType));
        System.assertEquals(true, AutomationBypass.isFlowBypassed('CONTACT'));
        System.assertEquals(false, AutomationBypass.isTriggerBypassed('AnyHandler', Opportunity.SObjectType));
        System.assertEquals(false, AutomationBypass.isValidationBypassed());
    }

    @IsTest
    static void handlerListMatchesOnlyThatHandler() {
        AutomationBypass.settingOverride = new Automation_Bypass__c(
            Bypassed_Handlers__c = 'AccountTriggerHandler',
            Expires_At__c = Datetime.now().addHours(1)
        );
        System.assertEquals(true, AutomationBypass.isTriggerBypassed('accounttriggerhandler', Account.SObjectType));
        System.assertEquals(false, AutomationBypass.isTriggerBypassed('ContactTriggerHandler', Contact.SObjectType));
    }

    @IsTest
    static void flowAndValidationSwitchesAreIndependent() {
        AutomationBypass.settingOverride = new Automation_Bypass__c(
            Bypass_Flows__c = true,
            Expires_At__c = Datetime.now().addHours(1)
        );
        System.assertEquals(true, AutomationBypass.isFlowBypassed('Account'));
        System.assertEquals(false, AutomationBypass.isValidationBypassed());
        System.assertEquals(false, AutomationBypass.isTriggerBypassed('AnyHandler', Account.SObjectType));

        AutomationBypass.settingOverride = new Automation_Bypass__c(
            Bypass_Validation_Rules__c = true,
            Expires_At__c = Datetime.now().addHours(1)
        );
        System.assertEquals(true, AutomationBypass.isValidationBypassed());
        System.assertEquals(false, AutomationBypass.isFlowBypassed('Account'));
    }

    @IsTest
    static void runtimeBypassesLastUntilCleared() {
        AutomationBypass.bypassHandler('AccountTriggerHandler');
        System.assertEquals(true, AutomationBypass.isTriggerBypassed('AccountTriggerHandler', Account.SObjectType));
        AutomationBypass.clearHandler('AccountTriggerHandler');
        System.assertEquals(false, AutomationBypass.isTriggerBypassed('AccountTriggerHandler', Account.SObjectType));

        AutomationBypass.bypassObject(Contact.SObjectType);
        System.assertEquals(true, AutomationBypass.isTriggerBypassed('X', Contact.SObjectType));
        System.assertEquals(true, AutomationBypass.isFlowBypassed('Contact'));
        AutomationBypass.clearObject(Contact.SObjectType);
        System.assertEquals(false, AutomationBypass.isFlowBypassed('Contact'));

        AutomationBypass.bypassAll();
        System.assertEquals(true, AutomationBypass.isValidationBypassed());
        AutomationBypass.clearRuntime();
        System.assertEquals(false, AutomationBypass.isValidationBypassed());
    }

    @IsTest
    static void parseListHandlesBlanksAndSeparators() {
        System.assertEquals(0, AutomationBypass.parseList(null).size());
        System.assertEquals(0, AutomationBypass.parseList('  ').size());
        Set<String> parsed = AutomationBypass.parseList('Account, Contact;Lead  Case');
        System.assertEquals(new Set<String>{ 'account', 'contact', 'lead', 'case' }, parsed);
    }
}
