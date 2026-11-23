/**
 * Base class for trigger handlers that respect AutomationBypass.
 *
 * Usage:
 *   trigger AccountTrigger on Account (before insert, before update, after insert, after update) {
 *       new AccountTriggerHandler().run();
 *   }
 *
 *   public with sharing class AccountTriggerHandler extends TriggerHandler {
 *       protected override void beforeInsert() { ... }
 *   }
 *
 * Override only the events you need. run() skips the handler when it, its
 * object or all triggers are bypassed for the running user or transaction.
 */
public virtual class TriggerHandler {

    @TestVisible
    protected System.TriggerOperation operation;
    @TestVisible
    protected List<SObject> newRecords;
    @TestVisible
    protected List<SObject> oldRecords;
    @TestVisible
    protected Map<Id, SObject> newMap;
    @TestVisible
    protected Map<Id, SObject> oldMap;

    private String handlerName;

    public TriggerHandler() {
        // Read the class name before any records are attached, so String.valueOf stays cheap on bulk loads.
        String description = String.valueOf(this);
        Integer colon = description.indexOf(':');
        this.handlerName = colon > 0 ? description.substring(0, colon) : description;

        if (Trigger.isExecuting) {
            this.operation = Trigger.operationType;
            this.newRecords = Trigger.new;
            this.oldRecords = Trigger.old;
            this.newMap = Trigger.newMap;
            this.oldMap = Trigger.oldMap;
        }
    }

    /** Returns true if the handler ran, false if it was skipped. */
    public Boolean run() {
        if (operation == null) {
            return false;
        }
        if (AutomationBypass.isTriggerBypassed(getHandlerName(), getSObjectType())) {
            return false;
        }
        switch on operation {
            when BEFORE_INSERT { beforeInsert(); }
            when BEFORE_UPDATE { beforeUpdate(); }
            when BEFORE_DELETE { beforeDelete(); }
            when AFTER_INSERT { afterInsert(); }
            when AFTER_UPDATE { afterUpdate(); }
            when AFTER_DELETE { afterDelete(); }
            when AFTER_UNDELETE { afterUndelete(); }
        }
        return true;
    }

    /** The handler's class name, used to match Bypassed_Handlers__c. */
    public String getHandlerName() {
        return handlerName;
    }

    public SObjectType getSObjectType() {
        if (newRecords != null && !newRecords.isEmpty()) {
            return newRecords.getSObjectType();
        }
        if (oldRecords != null && !oldRecords.isEmpty()) {
            return oldRecords.getSObjectType();
        }
        return null;
    }

    protected virtual void beforeInsert() {}
    protected virtual void beforeUpdate() {}
    protected virtual void beforeDelete() {}
    protected virtual void afterInsert() {}
    protected virtual void afterUpdate() {}
    protected virtual void afterDelete() {}
    protected virtual void afterUndelete() {}
}
