# Usage analytics

Optional aggregate analytics is enabled by default in both FOSS and cloud builds.
This is an opt-out model, not affirmative opt-in consent. First-run onboarding
highlights the behavior after feature setup and before the optional cloud account
step. Next, swiping past, or skipping the lessons preserves the current preference.
“Turn off usage sharing” and the close button save an opt-out and continue setup.
Settings → Data → Share usage statistics can change it later. Existing saved
opt-outs are preserved, including on upgrade; Next never re-enables them.
Replaying the tour does not prompt again. Settings ZIP backups omit this local
preference and imports cannot override it.

Cloud service counts require both local usage sharing and the account usage
preference. New accounts default on; existing saved account opt-outs are preserved.
Turning off the local setting also suppresses optional service counts on this
installation. Essential service records are independent of both switches.

No PostHog SDK runs in the app. Only enumerated actions go to Janan's first-party
`usage` relay; there are no health values, text, account/device identifiers,
recordings, automatic capture, crash payloads or persistent event queues. Turning
app analytics off closes pending HTTP clients. Already transmitted requests
cannot be recalled. Offline/network failures are dropped, never retried.

The relay validates the enabled flag and event allowlist, applies a shared
6,000-request/minute budget without IP or account-derived rate keys, and exports
batches of 20 counts to
PostHog with one shared aggregate identity and IP enrichment disabled. The host
necessarily processes connection metadata. Neither analytics relay derives or
stores IP hashes. A shared budget can drop metrics during abusive traffic; it
never limits diary features. Underfilled daily batches and failed
exports are omitted; these figures are approximate event counts, not unique
users, retention, billing totals, or a count of all installations.

Essential cloud authentication, security, billing, quotas and service-operation
records remain independent of analytics consent. They stay in the service's
operational stores and are not exported as user-level PostHog events.

## Build configuration

`JANAN_USAGE_URL` is an HTTPS first-party relay URL, supplied as a Dart define.
Without it the app performs no analytics requests even when the switch is on.
The public release workflow uses `config/usage.production.json`. Custom builds
can omit it or use their own relay. No PostHog token belongs in the public client.

```sh
.fvm/flutter_sdk/bin/flutter build apk --flavor foss \
  --dart-define-from-file=config/usage.production.json
```

Android `prod` is labelled `cloud`; the cloud web composer supplies
`JANAN_BUILD=cloud`. Other builds use the `foss` event prefix. Allowed actions are
`app_opened`, `home_opened`, `weight_opened`, `medications_opened`,
`nutrition_opened`, `statistics_opened` and `settings_opened`.
An app start is counted on startup with usage sharing, or when it is enabled
mid-session. Destination counts record changes of the selected shell tab.

## Dashboard and delivery

[PostHog usage dashboard](https://eu.posthog.com/project/320982/dashboard/1115575)
shows app starts, feature openings by build and enabled cloud service outcomes.
Every chart sums `aggregate_count`; counting PostHog rows would undercount by 20.
Its definitions are implementation metrics, not approved Data Catalog metrics.

The cloud repository owns the deployed relay, aggregate allowlist migration,
PostHog server configuration and cloud action instrumentation. Releasing the
updated clients is still required for real traffic. Before a composed release,
advance the cloud `base.lock` to a public commit containing this change using the
normal composition/release process; do not publish a dirty validation composition.

## Privacy boundary and compliance limits

The application payload contains only an enumerated event and `consent: true`.
`consent` is a legacy wire field meaning reporting is enabled, not evidence of
express consent. PostHog receives an allowlisted event, count, UTC day and the
same `janan-aggregate` identity for everyone, with person profiles and GeoIP
disabled and `$ip: null`. It receives no user IP, phone model, IMEI/IMSI,
Android/advertising ID, account ID, location, health values, URLs, text or recordings.
Batch thresholds count events, not distinct people: they do not establish
k-anonymity or a formal de-identification guarantee.

Network providers still see connection metadata (including IP and browser headers),
and hosted cloud operations require account identity. Provider request logs,
retention, region, access controls and contracts must be reviewed separately;
this implementation cannot promise zero identifiable data across all infrastructure.

HIPAA is US law applying to covered entities and business associates, not a global
certification. This change does not establish HIPAA compliance or Safe Harbor
de-identification. See [HHS applicability](https://www.hhs.gov/hipaa/for-professionals/covered-entities/index.html)
and [HHS de-identification guidance](https://www.hhs.gov/hipaa/for-professionals/special-topics/de-identification/index.html).
Default-on collection also requires assessment under the laws applicable to each
market; removing identifiers alone does not establish permission to collect.

The default-on client changes, cloud gateway changes and default migration must
be released together. The previously deployed relay still uses the older rate
limiter until the updated functions are deployed. Do not claim the new backend
privacy behavior is live based solely on passing local tests.
