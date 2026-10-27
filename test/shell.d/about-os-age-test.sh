#!/bin/bash
#
# The About box's OS Age counts days since the system was installed, from the
# birth time of /var/log. Not of /: the 4.5 installer writes a root filesystem
# image built with the ISO, so / is born when the ISO was built, and the age
# read from it was days too old, or negative where the installed machine's
# clock ran behind the build's (4.5.0rc2: "-10 days"). /var/log is the @log
# subvolume the installer creates on every install, archinstall's and the
# image's alike, and on a system set up by hand it dates from pacstrap, as /
# does.

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

command=$(jq -r '.modules[] | objects | select(.key? | tostring | test("OS Age")) | .text' \
  < <(sed 's#^\s*//.*##' "$ROOT/etc/fastfetch/config.jsonc"))
[[ -n $command ]] || fail "the fastfetch config has an OS Age command"

# A machine installed 3 days ago from an image built 10 days in its future.
now=1793200000
mkdir -p "$tmp_dir/bin"
cat >"$tmp_dir/bin/date" <<STUB
#!/bin/bash
echo $now
STUB
cat >"$tmp_dir/bin/stat" <<STUB
#!/bin/bash
case "\${@: -1}" in
  /var/log) echo $((now - 3 * 86400)) ;;
  /) echo $((now + 10 * 86400)) ;;
  *) echo 0 ;;
esac
STUB
cat >"$tmp_dir/bin/omarchy-i18n" <<'STUB'
#!/bin/bash
echo "$4 days"
STUB
chmod +x "$tmp_dir/bin/"*

age=$(PATH="$tmp_dir/bin:$PATH" bash -c "$command")
[[ $age == "3 days" ]] || fail "OS Age counts from the install, not the image build" "got: $age"
pass "OS Age counts from the install, not the image build"
