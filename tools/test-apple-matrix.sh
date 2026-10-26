#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodebuild >/dev/null
command -v python3 >/dev/null
mkdir -p test-results
xcrun simctl list devices available --json > test-results/available-devices.json
python3 - <<'PY' > test-results/destinations.tsv
import json
data=json.load(open('test-results/available-devices.json'))
devices=[x for group in data['devices'].values() for x in group if x.get('isAvailable')]
chosen=[]
for name, predicate in [('phone',lambda s:'iPhone' in s),('mini',lambda s:'iPad mini' in s),('air',lambda s:'iPad Air' in s),('pro',lambda s:'iPad Pro' in s)]:
    matches=[d for d in devices if predicate(d['name'])]
    if matches: chosen.append((name,matches[-1]['udid']))
if not any(n=='phone' for n,_ in chosen) or not any(n!='phone' for n,_ in chosen):
    raise SystemExit('Install at least one iPhone and one iPad simulator in Xcode.')
for name,udid in chosen: print(name+'\t'+udid)
PY
while IFS=$'\t' read -r name udid; do
  result="test-results/${name}-$(date +%Y%m%d-%H%M%S).xcresult"
  xcodebuild test -project BridgeApp/Bridge.xcodeproj -scheme Bridge \
    -destination "platform=iOS Simulator,id=${udid}" \
    -resultBundlePath "$result" CODE_SIGNING_ALLOWED=NO
done < test-results/destinations.tsv
