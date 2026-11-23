/**
 * Flow action: "Check Automation Bypass".
 * Add it as the first element of a record-triggered or autolaunched Flow,
 * then use a Decision to end the Flow when Is Bypassed is true.
 */
public with sharing class BypassFlowCheck {

    public class Request {
        @InvocableVariable(label='Object API Name' description='Object the Flow runs on, for example Account. Optional.')
        public String objectApiName;
    }

    public class Result {
        @InvocableVariable(label='Is Bypassed' description='True when this Flow should stop without doing anything.')
        public Boolean isBypassed;
    }

    @InvocableMethod(label='Check Automation Bypass' description='Returns whether Flows are bypassed for the running user.' category='Automation Bypass')
    public static List<Result> check(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request request : requests) {
            Result result = new Result();
            result.isBypassed = AutomationBypass.isFlowBypassed(request == null ? null : request.objectApiName);
            results.add(result);
        }
        return results;
    }
}
