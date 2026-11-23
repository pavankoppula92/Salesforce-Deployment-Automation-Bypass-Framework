// Turn the bypass off as soon as the load or deployment finishes.
//   sf apex run --file scripts/apex/disable-bypass.apex --target-org myorg

String username = 'migration.user@yourcompany.com';
Id userId = [SELECT Id FROM User WHERE Username = :username LIMIT 1].Id;
Boolean removed = AutomationBypassAdmin.disable(userId, 'Load finished');
System.debug(LoggingLevel.INFO, removed ? 'Bypass disabled' : 'No bypass was active');
