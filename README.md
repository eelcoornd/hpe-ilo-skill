# hpe-skills

[OpenClaw](https://docs.openclaw.ai) skills for managing and monitoring
HPE gear.

| Skill | What it does |
|-------|--------------|
| [`hpe-ilo`](skills/hpe-ilo/) | Drive HPE iLO 4/5/6 servers via the Redfish REST API (power, health, thermals, logs, virtual media, firmware). |
| [`hpe-advisories`](skills/hpe-advisories/) | Daily digest of new HPE security advisories from NVD, filtered by a user-editable product list. |
| [`hpe-firmware`](skills/hpe-firmware/) | Watch HPE's public SDR for new ProLiant firmware packages (BIOS, iLO, NIC, controllers) across selected fwpp channels. |

Everything runs through plain `curl` + `jq` — no SDKs, no vendored client
libraries, no Playwright.

## Install

Point OpenClaw at this repo as an extra skills root, so it picks up
`skills/hpe-ilo/SKILL.md` (and any future skills added here):

```bash
git clone https://github.com/eelcoornd/hpe-ilo-skill.git ~/hpe-ilo-skill

# Add to ~/.openclaw/openclaw.json
#   "skills": { "load": { "extraDirs": ["~/hpe-ilo-skill/skills"] } }

openclaw gateway restart
openclaw skills list | grep hpe-ilo
```

Or install just this one skill in a standard skill root:

```bash
mkdir -p ~/.openclaw/skills/hpe-ilo
curl -fsSL https://raw.githubusercontent.com/eelcoornd/hpe-ilo-skill/main/skills/hpe-ilo/SKILL.md \
  -o ~/.openclaw/skills/hpe-ilo/SKILL.md
```

## Configure

### hpe-ilo

Set three env vars once per shell (or in `~/.openclaw/openclaw.json`
under `env`):

```bash
export ILO_HOST=ilo.example.com
export ILO_USER=Administrator
export ILO_PASS='...'
export ILO_INSECURE=1   # accept self-signed iLO certs
```

### hpe-advisories

Edit the product list at `skills/hpe-advisories/products.txt` — one
keyword per line. Defaults cover iLO, ProLiant, Synergy, Apollo, MSA,
3PAR, Nimble, Aruba, OneView.

Optional: get a free [NVD API key](https://nvd.nist.gov/developers/request-an-api-key)
for higher rate limits, then `export NVD_API_KEY=...`.

**Complement with HPE email subscription.** NVD lags HPE bulletins by
0–2 days. For zero-day-lag, sign in to your HPE account →
Preferences → Communications → subscribe to your product families.
HPE emails you when new bulletins hit.

## Use

### hpe-ilo

Ask the agent things like:

- "What's the power state of the iLO?"
- "Show me temperatures and fan speeds."
- "Reboot the server gracefully."
- "Set next boot to PXE and restart."
- "Mount http://nas/isos/debian.iso as virtual CD and boot from it."
- "Any critical events in the IML in the last day?"

### hpe-advisories

- "Any new HPE advisories today?"
- "Show HPE security bulletins from the last week affecting ProLiant."
- "Add MSA and Nimble to the watched products."

Or run the fetch script directly for cron:

```bash
skills/hpe-advisories/scripts/fetch.sh                        # last 24h
## Compatibility

`hpe-ilo` works with iLO 4, iLO 5, iLO 6. The Redfish surface is largely
identical; where iLO-specific extensions exist they're under `.Oem.Hpe.*`.

## License

MIT
