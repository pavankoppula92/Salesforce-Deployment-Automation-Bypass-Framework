@IsTest
private class BypassControllerTest {

    @IsTest
    static void blocksUsersWithoutPermission() {
        BypassController.permissionOverride = false;
        try {
            BypassController.getBypasses();
            System.assert(false, 'Expected a permission error');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Manage Automation Bypass'), e.getMessage());
        }
    }

    @IsTest
    static void enableListAndDisable() {
        BypassController.permissionOverride = true;
        Id userId = UserInfo.getUserId();

        BypassController.enableBypass(userId, false, true, true, false, 'Account', null, 3, 'Release 24.3 data fix');
        List<AutomationBypassAdmin.BypassInfo> bypasses = BypassController.getBypasses();
        System.assertEquals(1, bypasses.size());
        System.assertEquals('Triggers; Flows; Objects: Account', bypasses[0].scope);

        BypassController.disableBypass(userId, 'Done');
        System.assertEquals(0, BypassController.getBypasses().size());
        System.assertEquals(UserInfo.getOrganizationId(), BypassController.getOrgId());
    }

    @IsTest
    static void turnsValidationErrorsIntoReadableMessages() {
        BypassController.permissionOverride = true;
        try {
            BypassController.enableBypass(UserInfo.getUserId(), true, null, null, null, null, null, 500, 'Too long');
            System.assert(false, 'Expected a validation error');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('between 1 and'), e.getMessage());
        }
    }
}
