// Turn on a time-boxed bypass before a data load or deployment.
// Edit the values below, then run:
//   sf apex run --file scripts/apex/enable-bypass.apex --target-org myorg

String username = 'migration.user@yourcompany.com'; // the user that will load the data
Integer hours = 4;                                  // the bypass turns itself off after this
String reason = 'Wave 2 account migration';         // shows in the Bypass Log

AutomationBypassAdmin.Scope scope = new AutomationBypassAdmin.Scope();
scope.triggers = true;
scope.flows = true;
scope.validationRules = true;
// scope.objects = 'Account,Contact';               // or limit it to some objects
// scope.handlers = 'AccountTriggerHandler';        // or to some trigger handlers

Id userId = [SELECT Id FROM User WHERE Username = :username LIMIT 1].Id;
Automation_Bypass__c setting = AutomationBypassAdmin.enable(userId, scope, hours, reason);
System.debug(LoggingLevel.INFO, 'Bypass enabled for ' + username + ' until ' + setting.Expires_At__c);
