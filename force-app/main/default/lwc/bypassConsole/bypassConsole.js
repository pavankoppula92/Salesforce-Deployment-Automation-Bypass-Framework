import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import getBypasses from '@salesforce/apex/BypassController.getBypasses';
import enableBypass from '@salesforce/apex/BypassController.enableBypass';
import disableBypass from '@salesforce/apex/BypassController.disableBypass';
import getOrgId from '@salesforce/apex/BypassController.getOrgId';

const COLUMNS = [
    { label: 'Applies to', fieldName: 'targetName', wrapText: true },
    { label: 'Level', fieldName: 'level', initialWidth: 90 },
    { label: 'Bypassing', fieldName: 'scope', wrapText: true },
    { label: 'Reason', fieldName: 'reason', wrapText: true },
    {
        label: 'Expires',
        fieldName: 'expiresAt',
        type: 'date',
        typeAttributes: { month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }
    },
    { label: 'Status', fieldName: 'status', initialWidth: 100 },
    { type: 'action', typeAttributes: { rowActions: [{ label: 'Disable now', name: 'disable' }] } }
];

export default class BypassConsole extends LightningElement {
    columns = COLUMNS;
    rows = [];
    targetOptions = [
        { label: 'A user', value: 'user' },
        { label: 'Entire org', value: 'org' }
    ];
    targetType = 'user';
    userId;
    orgId;
    scope = { all: false, triggers: false, flows: false, validationRules: false };
    objects = '';
    handlers = '';
    hours = 4;
    reason = '';
    isSaving = false;

    connectedCallback() {
        this.load();
    }

    get isUserTarget() {
        return this.targetType === 'user';
    }

    get hasBypasses() {
        return this.rows.length > 0;
    }

    async load() {
        try {
            const [bypasses, orgId] = await Promise.all([getBypasses(), getOrgId()]);
            this.orgId = orgId;
            this.rows = bypasses.map((b) => ({ ...b, status: b.isExpired ? 'Expired' : 'Active' }));
        } catch (error) {
            this.toast('Could not load bypasses', this.errorMessage(error), 'error');
        }
    }

    handleTargetType(event) {
        this.targetType = event.detail.value;
    }

    handleUser(event) {
        this.userId = event.detail.recordId;
    }

    handleToggle(event) {
        this.scope = { ...this.scope, [event.target.dataset.field]: event.target.checked };
    }

    handleInput(event) {
        this[event.target.dataset.field] = event.target.value;
    }

    async handleEnable() {
        const targetId = this.isUserTarget ? this.userId : this.orgId;
        if (!targetId) {
            this.toast('Choose a user', 'Pick the user the bypass applies to.', 'warning');
            return;
        }
        if (!this.isUserTarget) {
            const confirmed = await LightningConfirm.open({
                message: 'This bypasses automation for every user in the org until it expires. Continue?',
                label: 'Bypass the entire org?',
                theme: 'warning'
            });
            if (!confirmed) {
                return;
            }
        }

        this.isSaving = true;
        try {
            await enableBypass({
                targetId,
                bypassAll: this.scope.all,
                triggers: this.scope.triggers,
                flows: this.scope.flows,
                validationRules: this.scope.validationRules,
                objects: this.objects,
                handlers: this.handlers,
                hours: parseInt(this.hours, 10),
                reason: this.reason
            });
            this.toast('Bypass enabled', `It expires in ${this.hours} hour(s).`, 'success');
            this.reason = '';
            await this.load();
        } catch (error) {
            this.toast('Could not enable the bypass', this.errorMessage(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async handleRowAction(event) {
        if (event.detail.action.name !== 'disable') {
            return;
        }
        try {
            await disableBypass({ targetId: event.detail.row.targetId, reason: 'Disabled from the console' });
            this.toast('Bypass disabled', 'Automation is running again for this target.', 'success');
            await this.load();
        } catch (error) {
            this.toast('Could not disable the bypass', this.errorMessage(error), 'error');
        }
    }

    errorMessage(error) {
        return error?.body?.message || error?.message || 'Unknown error';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
