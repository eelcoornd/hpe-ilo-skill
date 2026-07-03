---
name: hpe-advisories
description: Fetch new HPE security advisories from NVD for a user-selected product list. Daily digest, no HPE login required.
metadata: { "openclaw": { "requires": { "bins": ["curl", "jq", "python3"] } } }
---

# HPE Advisories

Daily digest of new HPE security advisories, filtered by the products you
care about.

**Source: NIST NVD API v2** (public, no auth). NVD publishes every CVE
tagged to HPE within 0–2 days of HPE's own bulletin release.

Why not scrape support.hpe.com directly? Because it's a Salesforce SPA
behind Okta OIDC — needs a real browser + login. NVD gives us the same
CVEs as JSON, no credentials.

## Product list

The user's product list lives at `{baseDir}/products.txt`, one keyword
per line. Comments start with `#`.

```
# Default: uncomment/edit the ones that apply to your fleet
iLO
ProLiant
Synergy
Apollo
MSA
3PAR
Nimble
Aruba
OneView
```

To change: edit `{baseDir}/products.txt`, no restart needed.

## Fetch new advisories (last 24 h)

```bash
BASE="https://services.nvd.nist.gov/rest/json/cves/2.0"
SINCE=$(date -u -d '24 hours ago' +'%Y-%m-%dT%H:%M:%S.000')
UNTIL=$(date -u +'%Y-%m-%dT%H:%M:%S.000')

# One query per product keyword (NVD API only takes one keyword param)
while IFS= read -r product; do
  [[ -z "$product" || "$product" =~ ^# ]] && continue
  curl -sSL --get "$BASE" \
    --data-urlencode "keywordSearch=HPE $product" \
    --data-urlencode "pubStartDate=$SINCE" \
    --data-urlencode "pubEndDate=$UNTIL" \
  | jq --arg p "$product" '
      .vulnerabilities[] |
      {
        product: $p,
        cve: .cve.id,
        published: .cve.published,
        severity: (.cve.metrics.cvssMetricV31[0]?.cvssData.baseSeverity
                // .cve.metrics.cvssMetricV30[0]?.cvssData.baseSeverity
                // "n/a"),
        score:    (.cve.metrics.cvssMetricV31[0]?.cvssData.baseScore
                // .cve.metrics.cvssMetricV30[0]?.cvssData.baseScore
                // 0),
        summary:  .cve.descriptions[0].value,
        refs:     [.cve.references[].url]
      }'
done < {baseDir}/products.txt | jq -s 'unique_by(.cve) | sort_by(-.score)'
```

## Fetch over a custom window

Replace the `SINCE`/`UNTIL` lines:

```bash
SINCE=$(date -u -d '7 days ago' +'%Y-%m-%dT%H:%M:%S.000')   # weekly digest
SINCE='2026-01-01T00:00:00.000'                             # since a fixed date
```

Max window per query is 120 days (NVD limit).

## Formatting

For a human-readable digest, pipe the JSON into:

```bash
jq -r '.[] | "\(.severity)  \(.score)  \(.cve)  [\(.product)]  \(.summary[0:120])..."'
```

Or a Markdown table:

```bash
jq -r '["Severity","Score","CVE","Product","Summary"], (.[] | [.severity, .score, .cve, .product, (.summary[0:80])]) | @tsv' \
  | column -t -s $'\t'
```

## Daily cron

To auto-run and mail yourself the digest:

```bash
# /etc/cron.daily/hpe-advisories
#!/bin/bash
OUT=$({baseDir}/scripts/fetch.sh 2>&1)
[[ -n "$OUT" ]] && echo "$OUT" | mail -s "HPE advisories $(date +%F)" you@example.com
```

Or wire it via OpenClaw's built-in scheduler / a systemd timer on the host.

## Rate limits

NVD without an API key: 5 requests per 30 seconds. With ~10 products in
the list, one daily run is well under the limit. If you scan more than
30 products in one run, get a free NVD API key
(<https://nvd.nist.gov/developers/request-an-api-key>) and add
`--header "apiKey: $NVD_API_KEY"` to the curl call.

## What this does NOT do

- Doesn't log in to HPE's support portal (no personalized entitlements
  or warranty data).
- Doesn't grab the HPE bulletin PDF. Links from NVD's `refs` array
  usually include `support.hpe.com/hpesc/public/docDisplay?docId=...`
  which is a public URL you can open in a browser.
- Doesn't cover HPE advisories that HPE hasn't reserved a CVE for yet
  (rare, usually within days).

## References

- NVD API v2: <https://nvd.nist.gov/developers/vulnerabilities>
- HPE Security Bulletin Library (login-walled SPA):
  <https://support.hpe.com/connect/s/securitybulletinlibrary>
- HPE Support Alerts email subscription (recommended addition):
  Sign in to your HPE account → Preferences → Communications → subscribe
  to your product families. HPE emails you when new bulletins hit.
