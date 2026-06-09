# Metrics Shutdown Race Condition

Reproduces [heroku/barnes#58](https://github.com/heroku/barnes/issues/58): during dyno shutdown, the platform deregisters the dyno's UUID from the metrics endpoint ~1-6 seconds after SIGTERM. If the process is still alive (draining requests, finishing work), barnes continues posting metrics and receives:

```
barnes: metrics POST rejected (401): dynoidmap: no dyno information exists for that UUID
```

This warning repeats every 10 seconds until SIGKILL (30 seconds after SIGTERM), producing ~3 warnings per restart.

## How it works

The app traps SIGTERM and delays exit, simulating a real app with slow graceful shutdown (draining connections, finishing background jobs). This keeps the process alive long enough for the UUID to be deregistered while barnes is still posting.

## Setup

```bash
heroku create
heroku labs:enable "runtime-heroku-metrics" -a <app-name>
heroku labs:enable "ruby-language-metrics" -a <app-name>
heroku ps:type standard-1x -a <app-name>
```

## Deploy

```bash
git push heroku main
```

Wait ~30 seconds for the dyno to boot and start reporting metrics.

## Trigger the bug

Deploy again to trigger a restart:

```bash
git commit --allow-empty -m "trigger restart"
git push heroku main
```

## Observe

Wait ~60 seconds, then check the logs:

```bash
heroku logs -n 100 -a <app-name> | grep "barnes\|SIGTERM\|SIGKILL\|R12"
```

You should see:

```
Stopping all processes with SIGTERM
SIGTERM received at <timestamp>, delaying shutdown...
barnes: metrics POST rejected (401): dynoidmap: no dyno information exists for that UUID
barnes: metrics POST rejected (401): dynoidmap: no dyno information exists for that UUID
barnes: metrics POST rejected (401): dynoidmap: no dyno information exists for that UUID
Error R12 (Exit timeout) -> At least one process failed to exit within 30 seconds of SIGTERM
Stopping remaining processes with SIGKILL
```

## Notes

- Preboot is **not** required. The race condition occurs on any restart or deploy.
- The UUID is deregistered ~1-6 seconds after SIGTERM regardless of preboot.
- Apps that exit immediately on SIGTERM never see the 401 because they die before the UUID is removed.
