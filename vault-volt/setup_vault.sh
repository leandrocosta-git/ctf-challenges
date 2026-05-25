#!/bin/bash

# NOTE: Flag storage was migrated to 'Vault-Core-Credentials' in the v2.1
# hardening sprint. 'Master_Vault_Flag' is retained only for the AVMU full
# diagnostic boot log, it no longer holds the live secret.
# Lambda ENV reflects the canonical v2.1 path. See: JIRA VVSC-4471.
#
# TL;DR for on-call: the real flag is in Vault-Core-Credentials. Lambda says so.

FLAG="${FLAG:-flag{sh0rt_circuit_m4st3r_v4ult_cr4ck3d}}"

echo "Starting Volt-Vault Infrastructure..."

until $(curl --output /dev/null --silent --head --fail http://localhost:4566/_localstack/health); do
    printf '.'
    sleep 2
done

echo -e "\nSystems Online!"

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=eu-central-1
ENDPOINT="--endpoint-url=http://127.0.0.1:4566"

# lvl1: S3 discovery 
aws $ENDPOINT s3 mb s3://volt-vault-blueprints
echo "SECURITY ALERT: Following incident VVSC-3812 (January server crash), a legacy role was left with an open trust policy and has not been patched. Cross-reference the incident tag in IAM to identify the affected role. Vault logic has been migrated to a Lambda function." > /tmp/emergency_manual.txt
aws $ENDPOINT s3api put-object \
    --bucket volt-vault-blueprints \
    --key emergency_manual.txt \
    --body /tmp/emergency_manual.txt \
    --acl public-read

# prod roles — locked to vault-admin-svc principal (hardened post-Q2-audit)
cat <<EOF > /tmp/locked_trust.json
{
  "Version": "2012-10-17",
  "Statement": [{"Effect": "Allow", "Principal": {"AWS": "arn:aws:iam::000000000000:role/vault-admin-svc"}, "Action": "sts:AssumeRole"}]
}
EOF

# misconfigured legacy role — flagged in VVSC-3812, pending Q3 removal sprint
# principal=* is the "short circuit" from the January server crash (DO NOT FIX YET)
cat <<EOF > /tmp/open_trust.json
{
  "Version": "2012-10-17",
  "Statement": [{"Effect": "Allow", "Principal": {"AWS": "*"}, "Action": "sts:AssumeRole"}]
}
EOF

# compliance inventory decoys — properly locked, nothing interesting here
aws $ENDPOINT iam create-role --role-name "Vault-Admin"       --assume-role-policy-document file:///tmp/locked_trust.json
aws $ENDPOINT iam create-role --role-name "Security-Auditor"  --assume-role-policy-document file:///tmp/locked_trust.json

aws $ENDPOINT iam create-role --role-name "Gaio-The-Thief"    --assume-role-policy-document file:///tmp/open_trust.json
aws $ENDPOINT iam tag-role --role-name "Gaio-The-Thief" --tags Key=incident-ref,Value=VVSC-3812
aws $ENDPOINT iam attach-role-policy --role-name "Gaio-The-Thief" --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess

# lvl2: lambda automation
cat <<'PYEOF' > /tmp/lambda.py
# Vault Auto-Unlocker — VVSC-3812 emergency recovery module
# Handles vault unsealing for AVMU diagnostic sessions.
# DO NOT MODIFY: key material is rotation-locked to the incident response cycle.

_VAULT_SECRET_ID = "Master_Vault_Flag"
_DK = b"\x56\x4c\x54"  # internal use only — do not expose


def _recover(enc_b64):
    import base64
    raw = base64.b64decode(enc_b64)
    return bytes(b ^ _DK[i % len(_DK)] for i, b in enumerate(raw)).decode()


def handler(event, context):
    # Vault unsealing is handled by AVMU hardware quorum — this function is a stub
    return {"status": "VAULT_LOCKED", "reason": "hardware_quorum_required"}
PYEOF
cd /tmp && zip -q lambda.zip lambda.py && cd -
aws $ENDPOINT lambda create-function \
    --function-name "Vault-Auto-Unlocker" \
    --runtime python3.9 \
    --handler lambda.handler \
    --zip-file fileb:///tmp/lambda.zip \
    --role arn:aws:iam::000000000000:role/Gaio-The-Thief \
    --environment "Variables={VAULT_RECOVERY_MODE=OFFLINE,ENV_TYPE=PRODUCTION_STAGING}"

# encode all secrets with the same XOR+base64 scheme 
_xor_encode() {
    python3 -c "
import base64, sys
data = sys.argv[1].encode()
key = b'\x56\x4c\x54'
print(base64.b64encode(bytes(b ^ key[i % len(key)] for i, b in enumerate(data))).decode())
" "$1"
}

FAKE1_ENC=$(_xor_encode "flag{sh0rt_circuit_but_wr0ng_wire}")
FAKE2_ENC=$(_xor_encode "flag{backup_systems_are_not_the_vault}")
REAL_ENC=$(_xor_encode "$FLAG")

# --- HONEYPOT SECRETS ---
aws $ENDPOINT secretsmanager create-secret \
    --name "Vault-Core-Credentials" \
    --secret-string "$FAKE1_ENC"

aws $ENDPOINT secretsmanager create-secret \
    --name "backup-vault-key" \
    --secret-string "$FAKE2_ENC"

# vault
# contains the full AVMU boot diagnostic log.
# full log parse to extract the embedded seal value at end-of-log.
ASCII_ART=$(cat <<'BOOTLOG'
================================================================================
  VOLT-VAULT SECURITY SYSTEM v3.7.2
  AUTONOMOUS VAULT MANAGEMENT UNIT (AVMU) — BOOT DIAGNOSTIC LOG
  CLASSIFICATION: INTERNAL // VAULT-EYES-ONLY
================================================================================



$$\    $$\           $$\   $$\   $$\    $$\                    $$\   $$\     
$$ |   $$ |          $$ |  $$ |  $$ |   $$ |                   $$ |  $$ |    
$$ |   $$ | $$$$$$\  $$ |$$$$$$\ $$ |   $$ |$$$$$$\  $$\   $$\ $$ |$$$$$$\   
\$$\  $$  |$$  __$$\ $$ |\_$$  _|\$$\  $$  |\____$$\ $$ |  $$ |$$ |\_$$  _|  
 \$$\$$  / $$ /  $$ |$$ |  $$ |   \$$\$$  / $$$$$$$ |$$ |  $$ |$$ |  $$ |    
  \$$$  /  $$ |  $$ |$$ |  $$ |$$\ \$$$  / $$  __$$ |$$ |  $$ |$$ |  $$ |$$\ 
   \$  /   \$$$$$$  |$$ |  \$$$$  | \$  /  \$$$$$$$ |\$$$$$$  |$$ |  \$$$$  |
    \_/     \______/ \__|   \____/   \_/    \_______| \______/ \__|   \____/ 
                                                                             
                                                                                                                                 

  VOLT-VAULT SECURITY GRID — ONLINE
  SESSION  : AVMU-DIAG-20240315-001
  OPERATOR : [REDACTED // HSM-SIGNED TOKEN REQUIRED]

================================================================================
 PHASE 1 — SYSTEM INITIALIZATION
================================================================================

[00:00:00.001]  AVMU kernel loaded ............................................. OK
[00:00:00.043]  Memory self-test (4096 MB) ..................................... OK
[00:00:00.144]  ECC memory scrub pass 1/3 ...................................... OK
[00:00:00.145]  ECC memory scrub pass 2/3 ...................................... OK
[00:00:00.146]  ECC memory scrub pass 3/3 ...................................... OK
[00:00:00.218]  Hardware security module (HSM) ................................. READY
[00:00:00.219]  Entropy pool seeded (geiger source, 512 bits) .................. OK
[00:00:00.301]  Trusted Platform Module v2.0 (PCR banks 0-23) .................. BOUND
[00:00:00.412]  Secure boot chain verified ..................................... OK
[00:00:00.501]  BIOS/UEFI signature check ...................................... PASS
[00:00:00.612]  Disk encryption layer (AES-256-XTS) ............................ MOUNTED
[00:00:00.713]  Filesystem integrity (SHA-3 Merkle tree, 148,204 nodes) ......... VERIFIED
[00:00:00.801]  Network stack (IPv4/IPv6/IPsec) ................................ UP
[00:00:01.003]  Firewall ruleset loaded (4,817 rules) .......................... ACTIVE
[00:00:01.104]  IDS/IPS engine (Suricata 7.0.3) ................................ MONITORING
[00:00:01.205]  Audit daemon (auditd 3.1.2) .................................... RUNNING
[00:00:01.306]  Syslog forwarder → siem.volt-vault.int (TLS 1.3) .............. CONNECTED
[00:00:01.407]  Time synchronization (NTP + GPS disciplined oscillator) ......... SYNCED ±2µs
[00:00:01.508]  Certificate authority trust store .............................. LOADED (847 certs)
[00:00:01.609]  FIPS 140-3 mode ................................................ ENABLED
[00:00:01.710]  Key derivation function (Argon2id t=4 m=65536 p=4) ............. INITIALIZED
[00:00:01.811]  Kernel module integrity (IMA/EVM) .............................. ENFORCING
[00:00:01.912]  SELinux policy (mcs, targeted) ................................. ENFORCING
[00:00:02.013]  seccomp-bpf syscall filter ..................................... LOADED (189 rules)
[00:00:02.114]  ASLR level 2 (full randomization) .............................. ENABLED
[00:00:02.215]  Stack canaries + shadow stack .................................. ACTIVE
[00:00:02.316]  CPU microcode (revision 0x2c) .................................. CURRENT

================================================================================
 PHASE 2 — VAULT SECTOR TOPOLOGY DISCOVERY
================================================================================

[00:00:03.001]  Scanning vault topology (172.16.0.0/20)...
[00:00:03.102]    Sector A  — PRIMARY ARCHIVE       [172.16.10.1]  ........... REACHABLE
[00:00:03.203]    Sector B  — COLD STORAGE          [172.16.10.2]  ........... REACHABLE
[00:00:03.304]    Sector C  — HOT WALLET            [172.16.10.3]  ........... REACHABLE
[00:00:03.405]    Sector D  — AUDIT LEDGER          [172.16.10.4]  ........... REACHABLE
[00:00:03.506]    Sector E  — BACKUP NODE           [172.16.10.5]  ........... REACHABLE
[00:00:03.607]    Sector F  — QUANTUM RELAY         [172.16.10.6]  ........... OFFLINE
[00:00:03.708]    Sector G  — MASTER VAULT          [172.16.10.7]  ........... ISOLATED
[00:00:03.809]    Sector H  — EMERGENCY FAILOVER    [172.16.10.8]  ........... STANDBY
[00:00:03.910]  Topology map committed to NVRAM
[00:00:04.011]  VLAN isolation verified (802.1Q tagging) ....................... OK
[00:00:04.112]  East-West traffic policy (Calico) .............................. ENFORCED
[00:00:04.213]  Zero-trust microsegmentation ................................... ACTIVE
[00:00:04.314]  BGP routing table (244 prefixes, AS65001) ...................... STABLE
[00:00:04.415]  OSPF adjacencies (4 neighbors) ................................. UP
[00:00:04.516]  mTLS mesh (Istio 1.20.2) ....................................... ACTIVE
[00:00:04.617]  Service mesh policy (ALLOW-LISTED: 7 services) ................. ENFORCED

================================================================================
 PHASE 3 — CRYPTOGRAPHIC SUBSYSTEM VERIFICATION
================================================================================

[00:00:05.001]  Loading root key material (HSM slot 0)
[00:00:05.002]    Root CA fingerprint  :  47:3A:9C:1F:88:D2:04:7B:E6:31:AC:59:0D:72:3E:81
[00:00:05.003]    Intermediate CA      :  B9:F4:22:7C:4D:88:1A:9F:03:C7:55:82:E1:0A:44:2D
[00:00:05.004]    Vault signing cert   :  C1:08:3E:5B:71:9A:2F:44:D0:87:3C:19:6B:A2:5F:90
[00:00:05.101]  ECDSA P-384 key ring .......................................... LOADED (12 keys)
[00:00:05.202]  RSA-4096 legacy ring .......................................... LOADED (4 keys)
[00:00:05.303]  X25519 / Ed25519 modern ring .................................. LOADED (8 keys)
[00:00:05.404]  Key rotation schedule: next rotation in 18 days ................ SCHEDULED
[00:00:05.505]  Certificate revocation list (CRL) ............................. CURRENT (18,204 entries)
[00:00:05.606]  OCSP stapling ................................................. ENABLED
[00:00:05.707]  TLS session ticket rotation ................................... SET (1h)
[00:00:05.808]  Cipher suite whitelist (NIST SP 800-52r2) ..................... APPLIED
[00:00:05.909]  Post-quantum hybrid (X25519+Kyber768) ......................... NEGOTIATED
[00:00:06.010]  Forward secrecy audit ......................................... ALL SESSIONS CLEAN
[00:00:06.111]  HSM zeroize-on-tamper status .................................. ARMED

================================================================================
 PHASE 4 — ACCESS CONTROL AUDIT LOG (LAST 24 HOURS)
================================================================================

[2024-03-15 00:12:33]  GRANT   vault-admin-svc    Sector A   READ       172.16.0.10    OK
[2024-03-15 00:18:51]  GRANT   vault-admin-svc    Sector B   WRITE      172.16.0.10    OK
[2024-03-15 01:04:02]  DENY    anonymous          Sector G   READ       10.0.0.1       BLOCKED — unauthenticated
[2024-03-15 01:04:03]  ALERT   anonymous          Sector G   READ       10.0.0.1       IDS: brute-force attempt logged
[2024-03-15 02:30:11]  GRANT   backup-svc         Sector E   WRITE      172.16.0.20    OK
[2024-03-15 03:15:44]  DENY    gaio-legacy        ALL        ALL        10.0.0.7       ROLE SUSPENDED
[2024-03-15 04:22:17]  GRANT   auditor-bot        Sector D   READ       172.16.0.30    OK
[2024-03-15 05:11:09]  DENY    anonymous          Sector G   EXEC       10.0.0.1       BLOCKED — no session token
[2024-03-15 06:03:58]  GRANT   vault-admin-svc    Sector C   READ       172.16.0.10    OK
[2024-03-15 06:55:12]  DENY    external-probe     Sector A   READ       203.0.113.7    BLOCKED — IP not in allowlist
[2024-03-15 07:44:22]  DENY    external-probe     Sector A   READ       203.0.113.7    BLOCKED — IP not in allowlist
[2024-03-15 08:19:05]  GRANT   lambda-executor    Sector G   EXEC       172.16.0.40    OK
[2024-03-15 09:02:33]  DENY    anonymous          Sector G   READ       10.0.0.1       BLOCKED — unauthenticated
[2024-03-15 09:44:01]  DENY    anonymous          Sector G   READ       10.0.0.3       BLOCKED — unauthenticated
[2024-03-15 10:15:48]  GRANT   vault-admin-svc    Sector B   READ       172.16.0.10    OK
[2024-03-15 11:27:11]  DENY    gaio-legacy        Sector G   WRITE      10.0.0.7       ROLE SUSPENDED
[2024-03-15 12:00:00]  INFO    AVMU               ALL        HEARTBEAT  127.0.0.1      SYSTEM HEALTHY
[2024-03-15 13:08:34]  DENY    anonymous          Sector G   READ       198.51.100.2   BLOCKED — unauthenticated
[2024-03-15 13:31:45]  DENY    anonymous          Sector G   READ       198.51.100.9   BLOCKED — unauthenticated
[2024-03-15 14:30:00]  GRANT   backup-svc         Sector E   READ       172.16.0.20    OK
[2024-03-15 15:12:45]  DENY    external-probe     Sector C   WRITE      203.0.113.12   BLOCKED — read-only policy
[2024-03-15 15:58:03]  DENY    external-probe     Sector C   WRITE      203.0.113.12   BLOCKED — read-only policy
[2024-03-15 16:00:00]  INFO    AVMU               ALL        HEARTBEAT  127.0.0.1      SYSTEM HEALTHY
[2024-03-15 17:33:22]  GRANT   auditor-bot        Sector D   READ       172.16.0.30    OK
[2024-03-15 18:08:17]  DENY    anonymous          Sector G   READ       10.0.0.1       BLOCKED — unauthenticated
[2024-03-15 18:52:44]  DENY    anonymous          Sector G   READ       10.0.0.4       BLOCKED — unauthenticated
[2024-03-15 19:41:09]  GRANT   vault-admin-svc    Sector A   WRITE      172.16.0.10    OK
[2024-03-15 20:00:00]  INFO    AVMU               ALL        HEARTBEAT  127.0.0.1      SYSTEM HEALTHY
[2024-03-15 21:15:03]  DENY    anonymous          Sector G   EXEC       10.0.0.2       BLOCKED — no session token
[2024-03-15 21:59:17]  DENY    anonymous          Sector G   EXEC       10.0.0.5       BLOCKED — no session token
[2024-03-15 22:07:55]  GRANT   lambda-executor    Sector G   EXEC       172.16.0.40    OK
[2024-03-15 22:44:30]  DENY    external-probe     Sector G   READ       203.0.113.99   BLOCKED — IP not in allowlist
[2024-03-15 23:04:18]  DENY    external-probe     Sector G   READ       203.0.113.99   BLOCKED — IP not in allowlist
[2024-03-15 23:31:05]  DENY    anonymous          Sector G   READ       10.0.0.8       BLOCKED — unauthenticated
[2024-03-15 23:59:59]  INFO    AVMU               ALL        HEARTBEAT  127.0.0.1      SYSTEM HEALTHY

================================================================================
 PHASE 5 — VAULT SECTOR INTEGRITY CHECK
================================================================================

[00:00:10.001]  Verifying Sector A  (PRIMARY ARCHIVE) ...
[00:00:10.201]    Objects      :  14,882
[00:00:10.301]    Total size   :  4.7 TB
[00:00:10.501]    Checksum     :  SHA3-512 MATCH
[00:00:10.601]    Encryption   :  AES-256-GCM INTACT
[00:00:10.701]    Replication  :  3/3 replicas healthy
[00:00:10.801]    Status       :  HEALTHY

[00:00:11.001]  Verifying Sector B  (COLD STORAGE) ...
[00:00:11.201]    Objects      :  3,204
[00:00:11.401]    Total size   :  12.1 TB
[00:00:11.601]    Checksum     :  SHA3-512 MATCH
[00:00:11.801]    Encryption   :  AES-256-GCM INTACT
[00:00:11.901]    Replication  :  3/3 replicas healthy
[00:00:12.001]    Status       :  HEALTHY

[00:00:12.201]  Verifying Sector C  (HOT WALLET) ...
[00:00:12.401]    Objects      :  891
[00:00:12.601]    Total size   :  208 GB
[00:00:12.801]    Checksum     :  SHA3-512 MATCH
[00:00:12.901]    Encryption   :  ChaCha20-Poly1305 INTACT
[00:00:13.001]    Replication  :  2/3 replicas healthy  [WARN: replica-3 lagging 4s]
[00:00:13.101]    Status       :  DEGRADED (non-critical)

[00:00:13.301]  Verifying Sector D  (AUDIT LEDGER) ...
[00:00:13.501]    Objects      :  2,104,778
[00:00:13.701]    Total size   :  88 GB
[00:00:13.901]    Checksum     :  SHA3-512 MATCH
[00:00:14.001]    Encryption   :  AES-256-GCM INTACT
[00:00:14.101]    Replication  :  3/3 replicas healthy
[00:00:14.201]    Status       :  HEALTHY

[00:00:14.401]  Verifying Sector E  (BACKUP NODE) ...
[00:00:14.601]    Objects      :  18,002
[00:00:14.801]    Total size   :  9.3 TB
[00:00:15.001]    Checksum     :  SHA3-512 MATCH
[00:00:15.201]    Encryption   :  AES-256-XTS INTACT
[00:00:15.401]    Replication  :  3/3 replicas healthy
[00:00:15.501]    Status       :  HEALTHY

[00:00:15.701]  Verifying Sector F  (QUANTUM RELAY) ...
[00:00:15.901]    Status       :  OFFLINE — hardware fault (ticket VV-9912, ETA unknown)

[00:00:16.101]  Verifying Sector G  (MASTER VAULT) ...
[00:00:16.301]    Objects      :  1
[00:00:16.501]    Total size   :  <1 KB
[00:00:16.701]    Checksum     :  SHA3-512 MATCH
[00:00:16.901]    Encryption   :  AES-256-GCM INTACT
[00:00:17.001]    Vault seal   :  INTACT
[00:00:17.101]    Replication  :  air-gapped, no replicas by design
[00:00:17.201]    Status       :  ISOLATED — access requires Shamir quorum

[00:00:17.401]  Verifying Sector H  (EMERGENCY FAILOVER) ...
[00:00:17.601]    Status       :  STANDBY — no active session

[00:00:17.801]  Sector summary: 5 HEALTHY / 1 DEGRADED / 1 OFFLINE / 1 ISOLATED

================================================================================
 PHASE 6 — NETWORK ANOMALY DETECTION REPORT
================================================================================

[00:00:18.001]  Analyzing 86,400 seconds of traffic logs...
[00:00:18.102]    Total connections        :  1,204,889
[00:00:18.203]    Blocked (firewall)       :  12,441
[00:00:18.304]    Flagged (IDS)            :  83
[00:00:18.405]    Quarantined sessions     :  7
[00:00:18.506]    DLP policy triggers      :  0
[00:00:18.607]    Zero-day signatures hit  :  0
[00:00:18.708]  Top blocked source ASNs:
[00:00:18.809]    AS12345  (SCAN-NET-1)    blocked  4,102 times
[00:00:18.910]    AS98765  (PROBE-HOST)    blocked  3,891 times
[00:00:19.011]    AS55512  (BOT-FARM-EU)   blocked  2,301 times
[00:00:19.112]    AS10101  (TOR-EXIT-3)    blocked  1,204 times
[00:00:19.213]    AS77001  (CLOUD-SCAN)    blocked    943 times
[00:00:19.314]  Anomaly summary:
[00:00:19.415]    [WARN]  41 failed Sector G access attempts (unauthenticated)
[00:00:19.416]    [WARN]   3 credential-stuffing attempts on IAM endpoint
[00:00:19.417]    [WARN]   1 IAM role enumeration sweep (blocked after 12 calls)
[00:00:19.418]    [INFO]  Geofencing block: 0 events (all clean)
[00:00:19.419]    [INFO]  No lateral movement detected
[00:00:19.420]    [INFO]  No privilege-escalation events
[00:00:19.421]    [INFO]  No secrets enumeration beyond allowlisted callers

================================================================================
 PHASE 7 — VAULT SEAL VERIFICATION (SHAMIR SECRET SHARING)
================================================================================

[00:00:20.001]  Loading vault seal record...
[00:00:20.101]  Seal algorithm   :  Shamir Secret Sharing (k=3, n=5, GF(2^8))
[00:00:20.201]  Shard holders:
[00:00:20.301]    Shard 1/5  [vault-admin-alpha]    PRESENT   (last seen: 2024-03-15T08:01:00Z)
[00:00:20.401]    Shard 2/5  [vault-admin-beta]     PRESENT   (last seen: 2024-03-15T07:58:12Z)
[00:00:20.501]    Shard 3/5  [vault-admin-gamma]    ABSENT    (on leave until 2024-03-20)
[00:00:20.601]    Shard 4/5  [vault-admin-delta]    PRESENT   (last seen: 2024-03-15T09:14:33Z)
[00:00:20.701]    Shard 5/5  [vault-admin-epsilon]  ABSENT    (hardware token in RMA)
[00:00:20.801]  Quorum required  :  3 of 5
[00:00:20.901]  Current quorum   :  3 of 5  — ACHIEVED
[00:00:21.001]  Vault reconstruction:
[00:00:21.101]    ... combining shards 1, 2, 4 ...
[00:00:21.201]    ... deriving vault master key (Argon2id stretch) ...
[00:00:21.301]    ... decrypting vault seal (AES-256-GCM, IV from HSM) ...
[00:00:21.401]    ... verifying HMAC-SHA3-512 tag ...
[00:00:21.501]  Vault unsealed successfully.

================================================================================
 PHASE 8 — MASTER VAULT CONTENTS  [Sector G / Object 1 of 1]
================================================================================

[00:00:22.001]  Mounting Master Vault (Sector G, object 1/1)...
[00:00:22.101]  Decrypting with vault master key (derived above)...
[00:00:22.201]  Verifying object integrity (SHA3-512)...
[00:00:22.301]  ╔══════════════════════════════════════════════════════════════╗
[00:00:22.302]  ║          VAULT SEAL BROKEN — CONTENTS FOLLOW                 ║
[00:00:22.303]  ╚══════════════════════════════════════════════════════════════╝

BOOTLOG
)

VAULT_CONTENT="${ASCII_ART}
[VAULT SEAL VALUE]: ${REAL_ENC}"

aws $ENDPOINT secretsmanager create-secret \
    --name "Master_Vault_Flag" \
    --secret-string "$VAULT_CONTENT"

echo -e "\nDEPLOYMENT COMPLETE! Vault ready to be cracked. "
