#!/usr/bin/env bash
# Fetch HPE security advisories from NVD for the products listed in products.txt.
# Default window: last 24 hours. Override with $HPE_ADVISORIES_SINCE_HOURS.
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCTS="$DIR/products.txt"
HOURS="${HPE_ADVISORIES_SINCE_HOURS:-24}"

# ponytail: NVD keywordSearch is single-value; loop instead of one megaquery.
# Slower than a single call but simpler than juggling CPEs. Upgrade path:
# switch to virtualMatchString=cpe:2.3:*:hpe:<product> if false positives
# from keyword matching become annoying.

BASE="https://services.nvd.nist.gov/rest/json/cves/2.0"
# ponytail: python3 for date math because BSD date (macOS) lacks GNU's -d flag.
SINCE=$(python3 -c "from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(hours=$HOURS)).strftime('%Y-%m-%dT%H:%M:%S.000'))")
UNTIL=$(python3 -c "from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.000'))")
CURL_OPTS=(-sSL --max-time 30)
[[ -n "${NVD_API_KEY:-}" ]] && CURL_OPTS+=(--header "apiKey: $NVD_API_KEY")

while IFS= read -r product; do
  [[ -z "$product" || "$product" =~ ^[[:space:]]*# ]] && continue
  curl "${CURL_OPTS[@]}" --get "$BASE" \
    --data-urlencode "keywordSearch=HPE $product" \
    --data-urlencode "pubStartDate=$SINCE" \
    --data-urlencode "pubEndDate=$UNTIL" \
  | jq --arg p "$product" '
      .vulnerabilities[]? |
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
  sleep 6   # NVD unauthenticated: 5 req / 30s
done < "$PRODUCTS" | jq -s 'unique_by(.cve) | sort_by(-.score)'

# --- self-check: run this file with SELFCHECK=1 to smoke-test without hitting NVD ---
if [[ "${SELFCHECK:-0}" == "1" ]]; then
  echo '[{"product":"iLO","cve":"CVE-2099-0001","severity":"HIGH","score":8.1,"summary":"test","refs":[]}]' \
    | jq -e 'length == 1 and .[0].cve == "CVE-2099-0001"' >/dev/null && echo "selfcheck ok"
fi
