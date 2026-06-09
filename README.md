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
heroku logs --tail
```

You should see:

```
2026-06-09T16:13:36.866084+00:00 heroku[web.1]: Restarting
2026-06-09T16:13:36.923441+00:00 heroku[web.1]: State changed from up to starting
2026-06-09T16:13:38.140819+00:00 heroku[web.1]: Starting process with command `bundle exec puma -C- -p 57700`
2026-06-09T16:13:38.269578+00:00 heroku[web.1]: Stopping all processes with SIGTERM
2026-06-09T16:13:38.350656+00:00 app[web.1]: SIGTERM received at 2026-06-09 16:13:38 UTC, delaying shutdown...
2026-06-09T16:13:39.208953+00:00 app[web.1]: Puma starting in single mode...
2026-06-09T16:13:39.208976+00:00 app[web.1]: * Puma version: 8.0.2 ("Into the Arena")
2026-06-09T16:13:39.208977+00:00 app[web.1]: * Ruby version: ruby 3.3.9 (2025-07-24 revision f5c772fc7c) [x86_64-linux]
2026-06-09T16:13:39.208977+00:00 app[web.1]: *  Min threads: 0
2026-06-09T16:13:39.208978+00:00 app[web.1]: *  Max threads: 5
2026-06-09T16:13:39.208978+00:00 app[web.1]: *  Environment: production
2026-06-09T16:13:39.208979+00:00 app[web.1]: *          PID: 2
2026-06-09T16:13:39.245572+00:00 app[web.1]: * Listening on http://[::]:57700
2026-06-09T16:13:39.246829+00:00 app[web.1]: Use Ctrl-C to stop
2026-06-09T16:13:39.290403+00:00 heroku[web.1]: State changed from starting to up
2026-06-09T16:13:43.951281+00:00 app[web.1]: barnes: metrics POST rejected (401): dynoidmap: no dyno information exists for that UUID
2026-06-09T16:13:53.955331+00:00 app[web.1]: barnes: metrics POST rejected (401): dynoidmap: no dyno information exists for that UUID
2026-06-09T16:14:03.958345+00:00 app[web.1]: barnes: metrics POST rejected (401): dynoidmap: no dyno information exists for that UUID
2026-06-09T16:14:08.456434+00:00 heroku[web.1]: Error R12 (Exit timeout) -> At least one process failed to exit within 30 seconds of SIGTERM
2026-06-09T16:14:08.459506+00:00 heroku[web.1]: Stopping remaining processes with SIGKILL
2026-06-09T16:14:08.513680+00:00 heroku[web.1]: Process exited with status 137
```

## Notes

- Preboot is **not** required. The race condition occurs on any restart or deploy.
- The UUID is deregistered ~1-6 seconds after SIGTERM regardless of preboot.
- Apps that exit immediately on SIGTERM never see the 401 because they die before the UUID is removed.
