# Volt-Vault

**Author:** lrc\
**Category:** Cloud / Misc\
**Difficulty:** Easy\
**Services:** AWS S3, IAM, STS, Lambda, Secrets Manager (LocalStack)

---

## Lore

Volt-Vault Security prides itself on having the most secure digital vault in the world.

However, a short circuit in the central server scrambled the access permissions. You are a digital *lockpicker* hired to test whether, after this short circuit, it is possible to reach the **Master Vault** without keys.

No keys. No credentials. Only the short circuit.

---

## Objective

Reach the Master Vault and retrieve the flag.

---

## Setup

Make sure you have the following installed:
- [Docker](https://docs.docker.com/get-docker/)
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

Start your instance on CTFd and connect to the provided URL.

Configure the AWS CLI to point at your instance:

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=eu-central-1
export AWS_ENDPOINT=http://<your-instance-url>:4566
```

> No real AWS account is needed. All services run on a simulated environment.


## Attack Chain Summary

```
No credentials
      │
      ▼
S3 public object (emergency_manual.txt)
      │  reveals: incident reference VVSC-3812
      ▼
IAM role enumeration + tag lookup
      │  tag incident-ref=VVSC-3812 identifies the misconfigured role
      ▼
STS AssumeRole — trust policy Principal: * (no auth required)
      │  yields: temporary credentials
      ▼
Lambda get-function (download zip, inspect source)
      │  leaks: secret name + XOR decode key
      ▼
SecretsManager GetSecretValue (ReadOnlyAccess)
      │  returns: base64-encoded blob
      ▼
XOR decode with key from Lambda source
      │
      ▼
FLAG
```

---

## Vulnerability Summary

| Misconfiguration | Impact |
|---|---|
| S3 object with `public-read` ACL | Incident reference leaked to unauthenticated users |
| IAM trust policy `Principal: {"AWS": "*"}` | Any identity can assume the role — the "short circuit" |
| Secret name and decode key hardcoded in Lambda source | Exposed to anyone with `lambda:GetFunction` |
| `ReadOnlyAccess` includes `secretsmanager:GetSecretValue` | AWS managed policy is overly broad |

---

## Tools Used

- `aws` CLI with `--endpoint-url` pointing to LocalStack
- `--no-sign-request` for unauthenticated S3 access
- Standard STS, IAM, Lambda, and Secrets Manager API calls
- `python3` for XOR decode
