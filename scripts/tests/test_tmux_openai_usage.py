"""Offline regression tests; no real credentials or network requests are used."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


SCRIPTS = Path(__file__).resolve().parents[1]
MOCK_CODEX = """#!/usr/bin/env python3
import json, os, sys
initialized = False
for line in sys.stdin:
    message = json.loads(line)
    method = message['method']
    with open(os.environ['MOCK_CALLS'], 'a') as log:
        log.write(method + '\\n')
    with open(os.environ['MOCK_RESPONSE']) as fixture:
        response = json.load(fixture)
    if response.get('hang'):
        continue
    if method == 'initialize':
        response = {'result': {}}
    elif method == 'initialized':
        initialized = True
        continue
    elif method != 'account/rateLimits/read' or not initialized:
        response = {'error': {'message': 'invalid handshake or unexpected request'}}
    # Notifications can arrive between responses.
    print(json.dumps({'method': 'account/rateLimits/updated', 'params': {}}), flush=True)
    print(json.dumps(dict(response, id=message['id'])), flush=True)
"""
MOCK_CURL = """#!/usr/bin/env python3
import json, os
with open(os.environ['MOCK_CALLS'], 'a') as log:
    log.write('curl\\n')
with open(os.environ['MOCK_RESPONSE']) as fixture:
    print(json.dumps(json.load(fixture)))
print(os.environ.get('MOCK_HTTP_STATUS', '200'))
"""


class OpenAIUsageTests(unittest.TestCase):
    def setUp(self):
        temp_root = Path("/tmp/opencode")
        self.temp = tempfile.TemporaryDirectory(dir=temp_root if temp_root.is_dir() else None)
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        for name, contents in (
            ("codex", MOCK_CODEX),
            ("curl", MOCK_CURL),
            # Don't launch detached refresh jobs from renderer tests.
            ("nohup", "#!/bin/sh\nexit 0\n"),
        ):
            executable = self.bin / name
            executable.write_text(contents)
            executable.chmod(0o755)

        self.auth = self.home / ".codex/auth.json"
        self.auth.parent.mkdir()
        self.auth.write_text(json.dumps({"tokens": {"access_token": "fake-token"}}))
        self.cache = self.home / "usage.json"
        self.calls = self.home / "calls"
        self.fixture = self.home / "response.json"
        self.env = {
            key: value for key, value in os.environ.items()
            if not key.startswith(("OPENAI_", "OPENCODE_", "PI_", "CODEX_", "XDG_"))
        }
        self.env.update({
            "HOME": str(self.home),
            "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
            "CODEX_HOME": str(self.auth.parent),
            "OPENAI_USAGE_CACHE_PATH": str(self.cache),
            "MOCK_CALLS": str(self.calls),
            "MOCK_RESPONSE": str(self.fixture),
        })
        self.snapshot = {
            "planType": "pro",
            "primary": {"usedPercent": 23, "windowDurationMins": 300, "resetsAt": 2000000000},
            "secondary": {"usedPercent": 40, "windowDurationMins": 10080, "resetsAt": 2000500000},
        }
        self.respond({"result": {"rateLimits": self.snapshot}})

    def respond(self, response):
        self.fixture.write_text(json.dumps(response))

    def run_script(self, name):
        result = subprocess.run(
            ["bash", str(SCRIPTS / name)], env=self.env, capture_output=True,
            text=True, timeout=15, check=True,
        )
        self.assertEqual(result.stderr, "")
        return result.stdout

    def refresh(self):
        self.run_script("tmux-openai-refresh.sh")
        return json.loads(self.cache.read_text())

    def status(self):
        return self.run_script("tmux-openai-status.sh")

    def call_log(self):
        return self.calls.read_text().splitlines() if self.calls.exists() else []

    def write_cache(self, meters, age=180, **extra):
        cache = {"ts": int(time.time() - age) * 1000, "meters": meters, **extra}
        self.cache.write_text(json.dumps(cache))
        return cache

    def test_reads_pro_limits_through_codex_without_inference(self):
        cache = self.refresh()
        self.assertEqual(cache["source"], "codex")
        self.assertEqual(cache["planType"], "pro")
        self.assertEqual(cache["meters"]["primary"], {
            "remainingPercent": 77, "resetAtMs": 2000000000000, "windowSeconds": 18000,
        })
        self.assertEqual(cache["meters"]["weekly"]["remainingPercent"], 60)
        self.assertEqual(cache["meters"]["weekly"]["windowSeconds"], 604800)
        self.assertEqual(self.call_log(), ["initialize", "initialized", "account/rateLimits/read"])

    def test_plus_and_zero_usage_are_still_supported(self):
        self.snapshot.update(planType="plus", primary={"usedPercent": 0}, secondary=None)
        self.respond({"result": {"rateLimits": self.snapshot}})
        cache = self.refresh()
        self.assertEqual(cache["planType"], "plus")
        self.assertEqual(cache["meters"], {"primary": {"remainingPercent": 100}})
        self.assertEqual(self.status(), "OpenAI 0m | 100%")

    def test_explicit_legacy_auth_overrides_codex(self):
        legacy = self.home / "legacy-auth.json"
        legacy.write_text(json.dumps({"openai": {
            "type": "oauth", "access": "fake-legacy-token", "accountId": "fake-account",
        }}))
        self.env["OPENAI_AUTH_PATH"] = str(legacy)
        self.respond({"plan_type": "pro", "rate_limit": {
            "primary_window": {"used_percent": 12, "limit_window_seconds": 18000},
            "secondary_window": {"used_percent": 0, "reset_after_seconds": 3600},
        }})
        cache = self.refresh()
        self.assertEqual(cache["source"], "oauth")
        self.assertEqual(cache["meters"]["primary"]["remainingPercent"], 88)
        self.assertEqual(cache["meters"]["weekly"]["remainingPercent"], 100)
        self.assertEqual(self.call_log(), ["curl"])

    def test_expired_login_does_not_display_stale_plus_usage(self):
        old = self.write_cache({"primary": {"remainingPercent": 0}})
        self.respond({"error": {"code": -32603, "message": "GET usage failed: 401 Unauthorized"}})
        cache = self.refresh()
        self.assertEqual(cache["error"], "auth_required")
        self.assertEqual(cache["ts"], old["ts"])
        self.assertEqual(self.status(), "OpenAI login required")
        self.refresh()
        self.assertEqual(self.call_log().count("account/rateLimits/read"), 1)

    def test_first_fetch_auth_error_is_visible(self):
        self.respond({"error": {"message": "chatgpt authentication required to read rate limits"}})
        self.assertEqual(self.refresh()["error"], "auth_required")
        self.assertEqual(self.status(), "OpenAI login required")

    def test_success_clears_prior_auth_error(self):
        self.write_cache({"primary": {"remainingPercent": 0}}, error="auth_required")
        cache = self.refresh()
        self.assertNotIn("error", cache)
        self.assertIn("77%", self.status())

    def test_rate_limit_keeps_data_timestamp_and_backs_off(self):
        old = self.write_cache({"primary": {"remainingPercent": 70}})
        self.respond({"error": {"message": "GET usage failed: 429 Too Many Requests"}})
        cache = self.refresh()
        self.assertEqual(cache["ts"], old["ts"])
        self.assertEqual(cache["meters"], old["meters"])
        self.assertGreater(cache["cooldownUntil"], time.time() * 1000 + 14 * 60000)
        self.refresh()
        self.assertEqual(self.call_log().count("account/rateLimits/read"), 1)

    def test_transient_failure_is_throttled_without_losing_usage(self):
        old = self.write_cache({"primary": {"remainingPercent": 70}})
        self.respond({"error": {"message": "GET usage failed: 503 Service Unavailable"}})
        cache = self.refresh()
        self.assertEqual(cache["ts"], old["ts"])
        self.assertNotIn("error", cache)
        self.assertIn("70%", self.status())
        self.refresh()
        self.assertEqual(self.call_log().count("account/rateLimits/read"), 1)

    def test_fresh_single_window_does_not_refetch_every_minute(self):
        self.write_cache({"primary": {"remainingPercent": 70}}, age=90)
        self.refresh()
        self.assertEqual(self.call_log(), [])

    def test_reset_passed_triggers_refresh_after_minimum_interval(self):
        self.write_cache({"primary": {
            "remainingPercent": 0, "resetAtMs": int(time.time() - 10) * 1000,
        }}, age=90)
        self.assertEqual(self.refresh()["meters"]["primary"]["remainingPercent"], 77)

    def test_weekly_only_response_and_rendering(self):
        self.snapshot.update(primary=None, secondary={"usedPercent": 32})
        self.respond({"result": {"rateLimits": self.snapshot}})
        self.assertEqual(self.refresh()["meters"], {"weekly": {"remainingPercent": 68}})
        self.assertEqual(self.status(), "OpenAI 0m | 68%")

    def test_absent_reset_does_not_shift_percentages(self):
        self.write_cache({
            "primary": {"remainingPercent": 0}, "weekly": {"remainingPercent": 63},
        }, age=0)
        self.assertEqual(self.status(), "OpenAI 0m | 0% | 63%")

    def test_no_auth_renders_nothing(self):
        self.auth.unlink()
        self.write_cache({"primary": {"remainingPercent": 70}}, age=0)
        self.assertEqual(self.status(), "")

    def test_codex_uses_its_own_cache_by_default(self):
        self.env.pop("OPENAI_USAGE_CACHE_PATH")
        result = subprocess.run(
            ["bash", "-c", '. "$1"; tmux_usage_openai_cache_path', "bash", str(SCRIPTS / "tmux-usage-lib.sh")],
            env=self.env, capture_output=True, text=True, check=True,
        )
        self.assertEqual(result.stdout.strip(), str(self.auth.parent / ".tmux-openai-usage-cache.json"))

    def test_active_lock_prevents_duplicate_request(self):
        Path(str(self.cache) + ".lock").mkdir()
        self.run_script("tmux-openai-refresh.sh")
        self.assertEqual(self.call_log(), [])

    def test_bad_cache_recovers(self):
        self.cache.write_text("not json")
        self.assertEqual(self.refresh()["planType"], "pro")

    def test_helper_timeout_does_not_hang_tmux(self):
        self.respond({"hang": True})
        result = subprocess.run(
            ["python3", str(SCRIPTS / "tmux-openai-codex-usage.py"), str(self.bin / "codex"), "0.1"],
            env=self.env, capture_output=True, text=True, timeout=3,
        )
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "")


if __name__ == "__main__":
    unittest.main()
