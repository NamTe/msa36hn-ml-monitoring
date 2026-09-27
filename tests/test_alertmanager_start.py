"""Validate startup with dummy credentials; never contacts Telegram."""
import subprocess
import unittest
from pathlib import Path


class AlertmanagerStartupTest(unittest.TestCase):
    def test_credentials_are_validated_without_disclosure(self):
        script = Path(__file__).resolve().parents[1] / "config/alertmanager/start.sh"
        cases = [
            ("", "-123", False),
            ("123:dummy", "", False),
            ("badtoken", "-123", False),
            ("123:dummy", "oops", False),
            ("123:dummy\ninjected", "-123", False),
            ("123:dummy", "0", False),
            ("123:dummy", "-123", True),
        ]
        for token, chat, valid in cases:
            with self.subTest(chat=chat, valid=valid):
                result = subprocess.run(
                    ["docker", "run", "--rm", "--entrypoint", "/bin/sh",
                     "-v", f"{script}:/etc/alertmanager/start.sh:ro",
                     "-e", f"TELEGRAM_BOT_TOKEN={token}",
                     "-e", f"TELEGRAM_CHAT_ID={chat}",
                     "prom/alertmanager:v0.34.1",
                     "/etc/alertmanager/start.sh", "--check"],
                    capture_output=True, text=True, timeout=30,
                )
                self.assertEqual(result.returncode == 0, valid)
                self.assertNotIn("123:dummy", result.stdout + result.stderr)
                self.assertNotIn("injected", result.stdout + result.stderr)
                if not valid:
                    self.assertIn("Invalid", result.stderr)


if __name__ == "__main__":
    unittest.main()
