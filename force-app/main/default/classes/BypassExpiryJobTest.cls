@IsTest
private class BypassExpiryJobTest {

    @IsTest
    static void executeRemovesExpiredBypasses() {
        insert new Automation_Bypass__c(SetupOwnerId = UserInfo.getUserId(), Bypass_All__c = true,
            Expires_At__c = Datetime.now().addMinutes(-1), Reason__c = 'Forgotten load');
        Test.startTest();
        new BypassExpiryJob().execute(null);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Automation_Bypass__c]);
        System.assertEquals(1, [SELECT COUNT() FROM Bypass_Log__c WHERE Action__c = 'Expired']);
    }

    @IsTest
    static void schedulesFourJobs() {
        Test.startTest();
        List<Id> jobIds = BypassExpiryJob.scheduleEvery15Minutes();
        Test.stopTest();
        System.assertEquals(4, jobIds.size());
        System.assertEquals(4, [SELECT COUNT() FROM CronTrigger WHERE Id IN :jobIds]);
    }
}
