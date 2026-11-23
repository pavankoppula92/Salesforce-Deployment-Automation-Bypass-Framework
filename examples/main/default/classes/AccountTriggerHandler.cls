/**
 * Example handler. Fills in Rating on new and changed accounts, and is skipped
 * whenever Account triggers or this handler are bypassed, for example during a
 * data migration that already supplies clean values.
 */
public with sharing class AccountTriggerHandler extends TriggerHandler {

    protected override void beforeInsert() {
        setDefaultRating((List<Account>) newRecords);
    }

    protected override void beforeUpdate() {
        setDefaultRating((List<Account>) newRecords);
    }

    private static void setDefaultRating(List<Account> accounts) {
        for (Account account : accounts) {
            if (String.isBlank(account.Rating)) {
                account.Rating = 'Warm';
            }
        }
    }
}
