/**
 * Removes expired bypasses and logs them, so validation rules and Flows that
 * read the custom setting turn back on even if nobody remembers to disable them.
 *
 * Schedule it once from anonymous Apex:
 *   BypassExpiryJob.scheduleEvery15Minutes();
 */
public with sharing class BypassExpiryJob implements Schedulable {

    public static final String JOB_PREFIX = 'Automation Bypass Expiry';

    public void execute(SchedulableContext context) {
        AutomationBypassAdmin.expireOld();
    }

    /** Schedules four hourly jobs at :00, :15, :30 and :45. Returns their Ids. */
    public static List<Id> scheduleEvery15Minutes() {
        List<Id> jobIds = new List<Id>();
        for (Integer minute : new List<Integer>{ 0, 15, 30, 45 }) {
            String name = JOB_PREFIX + ' :' + String.valueOf(minute).leftPad(2, '0');
            jobIds.add(System.schedule(name, '0 ' + minute + ' * * * ?', new BypassExpiryJob()));
        }
        return jobIds;
    }
}
