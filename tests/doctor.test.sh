#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root=$(mktemp -d /tmp/ryoku-palette-doctor.XXXXXX)
trap 'rm -rf "$test_root"' EXIT
fake_bin="$test_root/bin"
palette="$test_root/colors.json"
mkdir -p "$fake_bin"
printf '%s\n' '{"primary":"#112233","surface":"#010203","onSurface":"#fefefe"}' > "$palette"

cat > "$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
if [[ $* == *ryoku-palette-bridge.service* ]]; then
  exit 0
fi
exit 1
EOF

cat > "$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
case ${*: -1} in
  */healthz) printf 'ok\n' ;;
  */v1/palette) cat "$FAKE_PALETTE" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$fake_bin/systemctl" "$fake_bin/curl"

output=$(RYOKU_PALETTE="$palette" \
  FAKE_PALETTE="$palette" \
  PATH="$fake_bin:$PATH" \
  "$project_root/doctor.sh")

grep -Fq 'Ryoku Palette Bridge is healthy.' <<< "$output"
grep -Fq 'ok   published palette matches' <<< "$output"

printf 'PASS: doctor reports a healthy bridge\n'
