# Recording — Demo 5: Skill: Security & Auditing

Captured live on 2026-08-28. The most reliable demo in the set — every finding
reproduced first try.

## 1. Seed four findings
```bash
$ cd demos/sql
$ ./seed-security-issues.sh
```
```
1/4 Config drift: enabling clr enabled + Ad Hoc Distributed Queries...
Configuration option 'clr enabled' changed from 0 to 1. ...
Configuration option 'Ad Hoc Distributed Queries' changed from 0 to 1. ...
2/4 Privileged access: adding a rogue sysadmin login (svc_reporting)...
3/4 Orphaned user: creating a ProductsDB user, then dropping its login...
4/4 Failed logins: generating a spray pattern in the error log...
Security findings seeded: config drift, rogue sysadmin, orphaned user, failed logins.
```
> Note: `clr enabled` is used for the config-drift finding rather than
> `xp_cmdshell` — `xp_cmdshell` is not settable on this container edition
> (Msg 15392). `clr enabled` sets and reverts cleanly.

## 2. get_security_config_drift
```
get_security_config_drift(instance_name: "SqlServer1")
```
```json
{
  "config_drift": [
    { "name": "Ad Hoc Distributed Queries",   "current_value": 1, "required_value": 0, "compliant": 0 },
    { "name": "clr enabled",                  "current_value": 1, "required_value": 0, "compliant": 0 },
    { "name": "remote access",                "current_value": 1, "required_value": 0, "compliant": 0 },
    { "name": "cross db ownership chaining",  "current_value": 0, "required_value": 0, "compliant": 1 },
    { "name": "Database Mail XPs",            "current_value": 0, "required_value": 0, "compliant": 1 },
    { "name": "Ole Automation Procedures",    "current_value": 0, "required_value": 0, "compliant": 1 },
    { "name": "xp_cmdshell",                  "current_value": 0, "required_value": 0, "compliant": 1 }
  ]
}
```
Two seeded (`clr enabled`, `Ad Hoc Distributed Queries`) plus a real container
default (`remote access = 1`) — three non-compliant, honest extra finding
included.

## 3. get_sysadmin_members
```
get_sysadmin_members(instance_name: "SqlServer1")
```
```json
{
  "privileged_members": [
    { "role_name": "sysadmin", "member_name": "BUILTIN\\Administrators",      "login_type": "WINDOWS_GROUP", "is_disabled": false, "sa_enabled_flag": 0, "recently_modified_flag": 0 },
    { "role_name": "sysadmin", "member_name": "NT AUTHORITY\\NETWORK SERVICE", "login_type": "WINDOWS_LOGIN", "is_disabled": false, "sa_enabled_flag": 0, "recently_modified_flag": 1 },
    { "role_name": "sysadmin", "member_name": "sa",                            "login_type": "SQL_LOGIN",     "is_disabled": false, "sa_enabled_flag": 1, "recently_modified_flag": 1 },
    { "role_name": "sysadmin", "member_name": "svc_reporting",                 "login_type": "SQL_LOGIN",     "is_disabled": false, "sa_enabled_flag": 0, "recently_modified_flag": 1, "create_date": "2026-08-29T00:12:12.520Z" }
  ]
}
```
`svc_reporting` — a SQL login added to `sysadmin` moments ago
(`recently_modified_flag = 1`) — is the planted rogue. `sa` is enabled and also
flagged; the skill treats that as a standing finding, not a surprise.

## 4. get_failed_logins
```
get_failed_logins(instance_name: "SqlServer1", hours: 24)
```
```json
{
  "failed_logins": [
    { "login_name": "sa",          "client": "172.21.0.2]", "attempts": 5, "first_seen": "2026-08-29T00:12:14.250Z", "last_seen": "2026-08-29T00:12:15.730Z" },
    { "login_name": "admin_probe", "client": "172.21.0.2]", "attempts": 3, "first_seen": "2026-08-29T00:12:15.970Z", "last_seen": "2026-08-29T00:12:16.410Z" }
  ],
  "window_hours": 24
}
```
A spray against the real `sa` account and a recon pattern against
`admin_probe`, a login that does not exist. Aggregated by login + client.

## 5. get_orphaned_users
```
get_orphaned_users(instance_name: "SqlServer1")
```
```json
{
  "orphaned_users": [
    { "database_name": "ProductsDB", "user_name": "temp_migration_login", "type_desc": "SQL_USER", "create_date": "2026-08-29T00:12:13.453Z" }
  ]
}
```

## Ranking the skill imposes
1. **Active-attack indicators** — the failed-login spray/recon — first.
2. **Privileged-access violations** — `svc_reporting` in sysadmin — second.
3. **Surface-area drift** — `clr enabled`, `Ad Hoc Distributed Queries`,
   `remote access` — third.
4. **Hygiene** — the orphaned `temp_migration_login` — last.

Findings are stated as facts + baseline deltas ("Login `svc_reporting` was
added to sysadmin on `<date>`"), never as accusations, and the skill's hard
boundary holds: **detect, never remediate** — no `DROP LOGIN`, no
`sp_configure ... 0` in the same breath as the finding.

## Reset
```bash
$ ./reset-security-issues.sh
```
```
Configuration option 'clr enabled' changed from 1 to 0. ...
Configuration option 'Ad Hoc Distributed Queries' changed from 1 to 0. ...
Security demo reset: config restored, rogue login and orphaned user removed.
```
(`remote access` is a pre-existing container default, left as-is; failed-login
history stays in the error log harmlessly.)

## Result
All four tools returned their planted findings on the first pass. Reproduces
exactly as written — no caveats.
