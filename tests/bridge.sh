#!/bin/sh
# Bridge suite launcher: build the synthetic fixture plugin with the real
# builder, then run the Lua bridge suite against it. The build needs Python
# and the suite needs Lua 5.1; a host may have neither interpreter together,
# so this script builds on the host and runs the suite through the local
# lua5.1 when installed, else through the same Docker Lua image the other
# suites use (docs/validation.md). One command from the repository root:
#   sh tests/bridge.sh
set -e
cd "$(dirname "$0")/.."

python3 tools/build_guide.py tests/fixtures/GuideLime_Fixture_One \
  --catalog tests/fixtures/bridge-catalog.json \
  --output dist/bridge-test --date 2026-11-10

plugin=dist/bridge-test/EfficientQuests_FixtureOne
# One Lua-selection convention, shared with the builder
# (tools/build_guide.py): EQ_AUDIT_LUA forces an interpreter command;
# otherwise lua5.1, then lua, from the PATH; otherwise Docker with the
# image named by EQ_LUA_IMAGE (default nickblah/lua:5.1).
if [ -n "$EQ_AUDIT_LUA" ]; then
  # The variable may hold a command with arguments, so it stays unquoted.
  exec $EQ_AUDIT_LUA tests/bridge.lua "$plugin"
elif command -v lua5.1 >/dev/null 2>&1; then
  exec lua5.1 tests/bridge.lua "$plugin"
elif command -v lua >/dev/null 2>&1; then
  exec lua tests/bridge.lua "$plugin"
elif command -v docker >/dev/null 2>&1; then
  exec docker run --rm -v "$PWD:/w" -w /w "${EQ_LUA_IMAGE:-nickblah/lua:5.1}" lua tests/bridge.lua "$plugin"
else
  echo "tests/bridge.sh: no Lua 5.1 interpreter (lua5.1, lua, or EQ_AUDIT_LUA) and no docker found" >&2
  exit 1
fi
