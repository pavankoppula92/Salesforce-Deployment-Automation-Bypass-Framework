@IsTest
private class BypassFlowCheckTest {

    private static BypassFlowCheck.Request request(String objectApiName) {
        BypassFlowCheck.Request r = new BypassFlowCheck.Request();
        r.objectApiName = objectApiName;
        return r;
    }

    @IsTest
    static void returnsOneResultPerRequest() {
        AutomationBypass.settingOverride = new Automation_Bypass__c(
            Bypassed_Objects__c = 'Account',
            Expires_At__c = Datetime.now().addHours(1)
        );
        List<BypassFlowCheck.Result> results = BypassFlowCheck.check(
            new List<BypassFlowCheck.Request>{ request('Account'), request('Contact'), null }
        );
        System.assertEquals(3, results.size());
        System.assertEquals(true, results[0].isBypassed);
        System.assertEquals(false, results[1].isBypassed);
        System.assertEquals(false, results[2].isBypassed);
    }

    @IsTest
    static void flowSwitchBypassesEveryFlow() {
        AutomationBypass.settingOverride = new Automation_Bypass__c(
            Bypass_Flows__c = true,
            Expires_At__c = Datetime.now().addHours(1)
        );
        System.assertEquals(true, BypassFlowCheck.check(new List<BypassFlowCheck.Request>{ request(null) })[0].isBypassed);
    }
}
