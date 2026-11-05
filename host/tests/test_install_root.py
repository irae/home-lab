import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class InstallRootTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        stub = self.root / "stub"
        stub.write_text('''#!/bin/sh
command="$(basename "$0") $*"
printf '%s\\n' "$command" >> "$TEST_ROOT/commands"
[ "$command" != "$FAIL_COMMAND" ] || exit 1
case "$command" in
    'id -u') echo "${TEST_UID:-0}" ;;
    'systemctl enable stacks-image-update.timer') touch "$TEST_ROOT/enabled" ;;
    'systemctl enable --now stacks-image-update.timer') touch "$TEST_ROOT/enabled" "$TEST_ROOT/active" ;;
    'systemctl is-enabled --quiet stacks-image-update.timer') test -f "$TEST_ROOT/enabled" ;;
    'systemctl is-active --quiet stacks-image-update.timer') test -f "$TEST_ROOT/active" ;;
esac
''')
        stub.chmod(0o755)
        for name in ("id", "cp", "sysctl", "systemctl", "systemd-analyze"):
            (self.root / name).symlink_to(stub)
        self.env = dict(os.environ, PATH=f"{self.root}:{os.environ['PATH']}",
                        TEST_ROOT=str(self.root), FAIL_COMMAND="")

    def run_installer(self, fail="", uid="0"):
        return subprocess.run(
            ["bash", str(Path(__file__).resolve().parents[1] / "install-root.sh")],
            env=dict(self.env, FAIL_COMMAND=fail, TEST_UID=uid),
            text=True, capture_output=True,
        )

    def test_install_and_rerun_leave_timer_enabled_and_active(self):
        for _ in range(2):
            result = self.run_installer()
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue((self.root / "enabled").exists())
            self.assertTrue((self.root / "active").exists())
        commands = (self.root / "commands").read_text().splitlines()
        self.assertTrue(commands[1].startswith("systemd-analyze verify "))
        self.assertIn("systemctl is-enabled --quiet stacks-image-update.timer", commands)
        self.assertIn("systemctl is-active --quiet stacks-image-update.timer", commands)
        self.assertLess(commands.index("sysctl -p /etc/sysctl.d/90-lan-ipv6-off.conf"),
                        commands.index("systemctl enable --now stacks-image-update.timer"))

    def test_validation_failure_stops_before_copy(self):
        result = self.run_installer("systemd-analyze verify /data/stacks/host/stacks-image-update.service /data/stacks/host/stacks-image-update.timer")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("cp ", (self.root / "commands").read_text())

    def test_failures_do_not_report_success(self):
        for command in (
            "cp /data/stacks/host/stacks-image-update.service /etc/systemd/system/stacks-image-update.service",
            "systemctl daemon-reload",
            "sysctl -p /etc/sysctl.d/90-lan-ipv6-off.conf",
            "systemctl enable --now stacks-image-update.timer",
            "systemctl is-enabled --quiet stacks-image-update.timer",
            "systemctl is-active --quiet stacks-image-update.timer",
        ):
            with self.subTest(command=command):
                result = self.run_installer(command)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertNotIn("install-root: done", result.stdout)

    def test_nonroot_stops_before_changes(self):
        result = self.run_installer(uid="1000")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.root / "commands").read_text(), "id -u\n")


if __name__ == "__main__":
    unittest.main()
