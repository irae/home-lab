import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class StacksImageUpdateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.stacks = self.root / "stacks"
        self.stacks.mkdir()
        stub = self.root / "docker"
        stub.write_text('''#!/bin/sh
printf '%s %s\\n' "$PWD" "$*" >> "$TEST_COMMANDS"
if [ "$PWD" = "$FAIL_DIR" ] && [ "$*" = "$FAIL_COMMAND" ]
then
    exit 1
fi
exit 0
''')
        stub.chmod(0o755)
        self.commands = self.root / "commands"
        self.env = dict(
            os.environ,
            PATH=f"{self.root}:{os.environ['PATH']}",
            LC_ALL="C",
            TEST_COMMANDS=str(self.commands),
            FAIL_DIR="",
            FAIL_COMMAND="",
        )
        self.script = str(Path(__file__).resolve().parents[1] / "stacks-image-update.sh")

    def add_stack(self, name):
        stack = self.stacks / name
        stack.mkdir()
        (stack / "compose.yaml").write_text("services: {}\n")
        return stack

    def run_worker(self, fail_dir="", fail_command=""):
        return subprocess.run(
            ["bash", self.script, str(self.stacks)],
            env=dict(self.env, FAIL_DIR=fail_dir, FAIL_COMMAND=fail_command),
            text=True,
            capture_output=True,
        )

    def recorded(self):
        if not self.commands.exists():
            return []
        return self.commands.read_text().splitlines()

    def test_local_and_registry_stacks_pull_without_registry_local_images(self):
        registry = self.add_stack("dozzle")
        local = self.add_stack("hermes")
        (self.stacks / "host").mkdir()

        result = self.run_worker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        commands = self.recorded()
        expected = []
        for stack in (registry, local):
            expected.extend([
                f"{stack} compose build --pull",
                f"{stack} compose pull --ignore-buildable",
                f"{stack} compose up -d",
            ])
        self.assertEqual(commands, expected)
        self.assertNotIn("--force-recreate", "\n".join(commands))
        self.assertNotIn(" compose pull\n", "\n".join(commands) + "\n")

    def test_build_failure_skips_up_and_continues(self):
        broken = self.add_stack("restricted-mail")
        healthy = self.add_stack("set-brainz")

        result = self.run_worker(str(broken), "compose build --pull")

        self.assertNotEqual(result.returncode, 0)
        commands = self.recorded()
        self.assertEqual(commands[0], f"{broken} compose build --pull")
        self.assertNotIn(f"{broken} compose up -d", commands)
        self.assertEqual(commands[-3:], [
            f"{healthy} compose build --pull",
            f"{healthy} compose pull --ignore-buildable",
            f"{healthy} compose up -d",
        ])

    def test_registry_pull_failure_skips_up(self):
        stack = self.add_stack("sabnzbd")

        result = self.run_worker(str(stack), "compose pull --ignore-buildable")

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.recorded(), [
            f"{stack} compose build --pull",
            f"{stack} compose pull --ignore-buildable",
        ])

    def test_missing_compose_file_is_an_error(self):
        result = self.run_worker()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no compose.yaml", result.stdout)
        self.assertEqual(self.recorded(), [])


if __name__ == "__main__":
    unittest.main()
