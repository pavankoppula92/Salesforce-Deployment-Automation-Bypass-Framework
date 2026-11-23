# Migration Runbook: Loading Data with Automation Bypassed

Use this runbook for any bulk load where org automation would slow the load down, fail on legacy data or cause side effects such as emails.

## 1. Before the load

- [ ] **Decide what to bypass, and no more.** Prefer object-level or handler-level bypasses over *All automation*.
- [ ] **List what the bypassed automation normally does**, for example default values, roll-ups, sharing or integrations, so you can reproduce what is still needed after the load.
- [ ] **Validate the data outside Salesforce first.** The validation rules you bypass are no longer protecting you.
- [ ] **Use a dedicated migration user**, so the bypass doesn't affect real users working in the org.
- [ ] **Run a sample load in a full or partial sandbox** with the same bypass settings.
- [ ] **Check that the expiry job is scheduled:** Setup → Scheduled Jobs → *Automation Bypass Expiry*.

## 2. Turn the bypass on

Console: Automation Bypass tab → *A user* → migration user → choose the switches → hours → reason (include the ticket number) → **Enable bypass**.

Pipeline:

```bash
sf apex run --file scripts/apex/enable-bypass.apex --target-org prod
```

Set the hours to the expected load time plus a margin. The bypass turns itself off when the time runs out.

## 3. Load

- Use the Bulk API (`sf data upsert bulk`, Data Loader in Bulk mode) with an external Id so that reruns are safe.
- Load parents before children, for example Accounts → Contacts → Opportunities.
- Watch for `UNABLE_TO_LOCK_ROW`. If it appears, sort the file by parent Id or reduce the batch size.

## 4. Turn the bypass off

Disable it as soon as the load ends. Don't wait for the expiry.

```bash
sf apex run --file scripts/apex/disable-bypass.apex --target-org prod
```

`scripts/load-with-bypass.sh` does steps 2–4 in one command and always disables the bypass, even if the load fails.

## 5. After the load

- [ ] Confirm the Bypass Log shows *Enabled* and *Disabled* entries for this load.
- [ ] Run whatever the bypassed automation would have done, for example recalculating roll-ups or a one-time batch for default values.
- [ ] Run data quality reports against the rules that were bypassed.
- [ ] Spot-check records in the UI as a normal user.

## Rollback

If the load has to be reversed, delete the inserted records by external Id with the bypass still on for the migration user, so delete triggers don't fail on half-loaded data. Then disable the bypass.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| A validation rule still fires | Its formula doesn't include the bypass condition. See the README |
| A Flow still runs | It doesn't start with the Check Automation Bypass action or a `$Setup` decision |
| A trigger still runs | Its handler doesn't extend `TriggerHandler` or call `AutomationBypass.isTriggerBypassed` |
| The bypass doesn't apply to the loading user | It was enabled for a different user. Check the console's *Applies to* column |
| The bypass turned off mid-load | It expired. Enable it again with more hours, and check the log |
