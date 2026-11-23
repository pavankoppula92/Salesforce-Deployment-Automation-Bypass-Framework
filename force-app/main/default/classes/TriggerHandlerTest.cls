@IsTest
private class TriggerHandlerTest {

    private class CountingHandler extends TriggerHandler {
        public Map<String, Integer> calls = new Map<String, Integer>();
        private void count(String eventName) {
            calls.put(eventName, (calls.containsKey(eventName) ? calls.get(eventName) : 0) + 1);
        }
        protected override void beforeInsert() { count('beforeInsert'); }
        protected override void beforeUpdate() { count('beforeUpdate'); }
        protected override void beforeDelete() { count('beforeDelete'); }
        protected override void afterInsert() { count('afterInsert'); }
        protected override void afterUpdate() { count('afterUpdate'); }
        protected override void afterDelete() { count('afterDelete'); }
        protected override void afterUndelete() { count('afterUndelete'); }
    }

    private static CountingHandler handlerFor(System.TriggerOperation operation) {
        CountingHandler handler = new CountingHandler();
        handler.operation = operation;
        handler.newRecords = new List<Account>{ new Account(Name = 'Test') };
        return handler;
    }

    @IsTest
    static void dispatchesEveryEvent() {
        Integer total = 0;
        for (System.TriggerOperation operation : System.TriggerOperation.values()) {
            CountingHandler handler = handlerFor(operation);
            System.assertEquals(true, handler.run(), 'Handler should run for ' + operation);
            total += handler.calls.values()[0];
        }
        System.assertEquals(System.TriggerOperation.values().size(), total);
    }

    @IsTest
    static void doesNothingOutsideATrigger() {
        CountingHandler handler = new CountingHandler();
        System.assertEquals(false, handler.run());
        System.assertEquals(null, handler.getSObjectType());
    }

    @IsTest
    static void skipsWhenItsHandlerIsBypassed() {
        CountingHandler handler = handlerFor(System.TriggerOperation.BEFORE_INSERT);
        AutomationBypass.bypassHandler(handler.getHandlerName());
        System.assertEquals(false, handler.run());
        System.assertEquals(true, handler.calls.isEmpty());
    }

    @IsTest
    static void skipsWhenItsObjectIsBypassed() {
        CountingHandler handler = handlerFor(System.TriggerOperation.AFTER_UPDATE);
        AutomationBypass.settingOverride = new Automation_Bypass__c(
            Bypassed_Objects__c = 'Account',
            Expires_At__c = Datetime.now().addHours(1)
        );
        System.assertEquals(false, handler.run());
    }

    @IsTest
    static void readsObjectTypeFromOldRecordsOnDelete() {
        CountingHandler handler = new CountingHandler();
        handler.operation = System.TriggerOperation.AFTER_DELETE;
        handler.oldRecords = new List<Contact>{ new Contact(LastName = 'Test') };
        System.assertEquals(Contact.SObjectType, handler.getSObjectType());
    }

    @IsTest
    static void handlerNameIsTheClassName() {
        String name = new CountingHandler().getHandlerName();
        System.assert(name.endsWith('CountingHandler'), 'Unexpected handler name: ' + name);
    }
}
