---
name: hpe-firmware
description: Watch HPE's public Software Delivery Repository (SDR) for new ProLiant firmware. Reports firmware packages published in the last N days across selected fwpp channels. Complements hpe-ilo (which reports what's installed) and hpe-advisories (which reports CVEs). No HPE login required — SDR is public.
metadata:
  openclaw:
    requires:
      bins: [curl, python3, gzip]
---

# hpe-firmware

## What this skill does

Polls HPE's public Software Delivery Repository at
https://downloads.linux.hpe.com/SDR/repo/ and reports firmware packages
(BIOS, iLO, NIC, storage controllers, PSU, drives, etc.) published in the
last N days for the fwpp channels the user has enabled.

Output is one JSON line per package, sorted newest first, across all
configured repos.

## Configuration

Edit `repos.txt` in this skill's directory. One SDR repo path per line
(relative to `SDR/repo/`), `#` for comments. Uncomment what matches your
fleet — Gen11 is enabled by default.

## Usage

```bash
skills/hpe-firmware/scripts/fetch.sh                       # last 7 days
HPE_FW_SINCE_DAYS=30 skills/hpe-firmware/scripts/fetch.sh  # last month
```

Sample output:
```json
{"repo":"fwpp-gen11/current","date":"2026-06-06","name":"firmware-ilo6","version":"1.77","summary":"..."}
```

## Cross-referencing with what's installed

The `hpe-ilo` skill (sibling in this repo) exposes installed firmware via
Redfish `/redfish/v1/UpdateService/FirmwareInventory`. To spot upgrades
available for a specific server, run both:

```bash
# what's installed
curl -sk -u "$ILO_USER:$ILO_PASS" \
  "https://$ILO_HOST/redfish/v1/UpdateService/FirmwareInventory?\$expand=." \
  | jq -r '.Members[] | "\(.Name)\t\(.Version)"'

# what's newly published upstream
skills/hpe-firmware/scripts/fetch.sh
```

Match on package name (`firmware-ilo6`, `firmware-system-a55`, etc.) and
compare versions. Automating that cross-ref is a future enhancement — for
now, a human eyeballs the two lists.

## Daily cron

```
17 6 * * *  /path/to/skills/hpe-firmware/scripts/fetch.sh > /tmp/hpe-fw.jsonl
```

Then feed the JSONL to the agent in the morning digest.

## Notes and limits

- SDR only publishes firmware distributed as RPMs (ProLiant firmware pack,
  MCP, SPP metadata). Standalone Smart Components (`.scexe`) and vendor
  drive firmware bundles are **not** in SDR — those need HPE Support Center
  with a valid warranty entitlement.
- The `current` symlink points to the latest release channel. Older
  channels (`11.90`, `12.10`, etc.) exist if you need a fixed baseline.
- No rate limit worth worrying about; each repo is one HTTP GET plus one
  gzipped XML.

<!-- ponytail: parses YUM repomd/primary.xml directly instead of dnf/createrepo_c.
     ~40 lines of python vs a whole toolchain. Upgrade path: swap to
     `dnf repoquery` if we ever need dependency resolution. -->
