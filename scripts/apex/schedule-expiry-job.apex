// Run once per org. Removes expired bypasses every 15 minutes and logs them.
//   sf apex run --file scripts/apex/schedule-expiry-job.apex --target-org myorg
BypassExpiryJob.scheduleEvery15Minutes();
