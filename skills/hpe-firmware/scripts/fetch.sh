#!/usr/bin/env bash
# Poll HPE SDR firmware repos and print packages published in the last N days.
# Public data, no auth. Env:
#   HPE_FW_SINCE_DAYS   default 7
#   HPE_FW_REPOS_FILE   default skills/hpe-firmware/repos.txt (relative to skill root)
set -euo pipefail

SINCE_DAYS="${HPE_FW_SINCE_DAYS:-7}"
BASE="https://downloads.linux.hpe.com/SDR/repo"

here="$(cd "$(dirname "$0")/.." && pwd)"
repos_file="${HPE_FW_REPOS_FILE:-$here/repos.txt}"

cutoff=$(python3 -c "import time; print(int(time.time()) - ${SINCE_DAYS}*86400)")

grep -vE '^\s*(#|$)' "$repos_file" | awk '{print $1}' | while read -r repo; do
  repomd="$BASE/$repo/repodata/repomd.xml"
  primary_href=$(curl -sf "$repomd" \
    | python3 -c "
import sys, xml.etree.ElementTree as ET
ns={'r':'http://linux.duke.edu/metadata/repo'}
root=ET.fromstring(sys.stdin.read())
for d in root.findall('r:data', ns):
    if d.get('type')=='primary':
        print(d.find('r:location', ns).get('href'))
        break
") || { echo "warn: could not read $repomd" >&2; continue; }

  curl -sf "$BASE/$repo/$primary_href" | gunzip \
    | python3 -c "
import sys, xml.etree.ElementTree as ET, datetime, json
ns={'c':'http://linux.duke.edu/metadata/common'}
cutoff=${cutoff}
repo='${repo}'
r=ET.fromstring(sys.stdin.read())
out=[]
for p in r.findall('c:package', ns):
    t=int(p.find('c:time', ns).get('build'))
    if t < cutoff: continue
    out.append({
        'repo': repo,
        'date': datetime.date.fromtimestamp(t).isoformat(),
        'name': p.find('c:name', ns).text,
        'version': p.find('c:version', ns).get('ver'),
        'summary': (p.find('c:summary', ns).text or '').strip(),
    })
for o in sorted(out, key=lambda x: x['date'], reverse=True):
    print(json.dumps(o))
"
done
