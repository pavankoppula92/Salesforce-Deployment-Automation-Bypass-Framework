@IsTest
private class AccountTriggerHandlerTest {

    @IsTest
    static void setsDefaultRating() {
        Account account = new Account(Name = 'Acme');
        insert account;
        System.assertEquals('Warm', [SELECT Rating FROM Account WHERE Id = :account.Id].Rating);
    }

    @IsTest
    static void skippedDuringRuntimeBypass() {
        AutomationBypass.bypassHandler('AccountTriggerHandler');
        Account account = new Account(Name = 'Migrated Co');
        insert account;
        System.assertEquals(null, [SELECT Rating FROM Account WHERE Id = :account.Id].Rating);
    }

    @IsTest
    static void skippedWhenAccountIsBypassedInTheSetting() {
        insert new Automation_Bypass__c(
            SetupOwnerId = UserInfo.getUserId(),
            Bypassed_Objects__c = 'Account',
            Expires_At__c = Datetime.now().addHours(1),
            Reason__c = 'Test load'
        );
        Account account = new Account(Name = 'Bulk Loaded Co');
        insert account;
        System.assertEquals(null, [SELECT Rating FROM Account WHERE Id = :account.Id].Rating);
    }
}
