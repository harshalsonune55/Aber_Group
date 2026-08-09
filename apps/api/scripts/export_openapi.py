#!/usr/bin/env python
"""Print the OpenAPI schema to stdout.

The Dart client in packages/api_client is generated from this. CI regenerates it
and fails if the result differs from what is committed, which turns backend/client
contract drift into a pull-request failure rather than a runtime error on an
agent's phone.
"""

from __future__ import annotations

import json
import sys

from aber.core.config import Environment, Settings
from aber.main import create_app


def main() -> int:
    app = create_app(Settings(env=Environment.TEST, metrics_enabled=False, log_level="ERROR"))
    json.dump(app.openapi(), sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
