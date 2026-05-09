#!/bin/sh
set -eu

/usr/bin/python3 "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/scripts/test_permission_alert.py"
