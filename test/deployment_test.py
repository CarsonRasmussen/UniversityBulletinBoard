"""Deployment checks without SSH, sudo, or changes to a real server.

Run: python -m unittest discover -s test -p deployment_test.py -v
Requires Python 3, Ruby, and Bash (Git Bash on Windows).
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASH = "C:/Program Files/Git/bin/bash.exe" if os.name == "nt" else shutil.which("bash")


class DeploymentTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=ROOT / "tmp")
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.bin = self.work / "bin"
        self.bin.mkdir()
        self.log = self.work / "calls"
        self.env = os.environ.copy()
        self.env.update(PATH=str(self.bin) + os.pathsep + self.env["PATH"],
                        CALLS=self.log.as_posix(), HOME=self.work.as_posix(), MOCK_BIN=self.bin.as_posix())

    def run_bash(self, script, env=None):
        return subprocess.run([BASH, "-c", 'export PATH="$(cd "$MOCK_BIN" && pwd):$PATH"; exec bash "$1"', "test", str(script)], cwd=ROOT, env=env or self.env,
                              text=True, capture_output=True, timeout=30)

    def fake(self, name, body):
        path = self.bin / name
        path.write_text("#!/usr/bin/env bash\nset -eu\n" + body + "\n", encoding="utf-8")
        path.chmod(0o755)

    def validator(self, **changes):
        env = self.env | dict(RAILS_ENV="production", SECRET_KEY_BASE="s" * 128,
            APP_HOST="campus.example.org", APP_PROTOCOL="https", MAIL_FROM="sender@example.org",
            SMTP_ADDRESS="smtp.example.org", SMTP_PORT="587", SMTP_USERNAME="sender@example.org",
            SMTP_PASSWORD="private-test-value", SOLID_QUEUE_IN_PUMA="true")
        env.update(changes)
        return subprocess.run(["ruby", "deploy/validate-env.rb"], cwd=ROOT, env=env,
                              text=True, capture_output=True, timeout=30)

    def test_environment_validates_without_disclosing_secrets(self):
        result = self.validator()
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertNotIn("private-test-value", result.stdout + result.stderr)
        self.assertNotIn("s" * 128, result.stdout + result.stderr)

    def test_environment_rejects_invalid_settings_without_disclosing_values(self):
        for key, value in {"APP_HOST": "https://example.org/path", "APP_PROTOCOL": "ftp",
                           "SMTP_PORT": "0", "SECRET_KEY_BASE": "short-secret",
                           "MAIL_FROM": "invalid", "SMTP_PASSWORD": "",
                           "SOLID_QUEUE_IN_PUMA": "false", "RAILS_ENV": "development"}.items():
            with self.subTest(key=key):
                result = self.validator(**{key: value})
                self.assertNotEqual(0, result.returncode)
                self.assertIn(key, result.stderr)
                self.assertNotIn("private-test-value", result.stderr)
                self.assertNotIn("short-secret", result.stderr)

    def test_bash_syntax(self):
        for script in [ROOT / "start.sh", *sorted((ROOT / "deploy").glob("*.sh"))]:
            result = subprocess.run([BASH, "-n", str(script)], capture_output=True, text=True)
            self.assertEqual(0, result.returncode, result.stderr)

    def test_package_excludes_local_data_and_preserves_server_storage(self):
        source = self.work / "source"
        (source / "deploy").mkdir(parents=True)
        shutil.copy(ROOT / "deploy/package.sh", source / "deploy/package.sh")
        for name in ["storage/production.sqlite3", "storage/upload", "tmp/mail", "log/production.log",
                     "config/master.key", ".env", "config/credentials/production.key",
                     "secret.pem", ".aws/config", ".git/config", "vendor/bundle/private"]:
            file = source / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text("local-private-sentinel")
        (source / "README.md").write_text("Application code")
        archive = self.work / "app.tar.gz"
        result = subprocess.run([BASH, str(source / "deploy/package.sh"), archive.as_posix()],
                                capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stderr)
        import tarfile
        with tarfile.open(archive) as package:
            files = [item for item in package.getmembers() if item.isfile()]
            self.assertEqual({"./README.md", "./deploy/package.sh"}, {item.name for item in files})
            for item in files:
                self.assertNotIn(b"local-private-sentinel", package.extractfile(item).read())
            target = self.work / "server"
            (target / "storage").mkdir(parents=True)
            (target / "storage/upload").write_text("server-upload")
            package.extractall(target, filter="data")
            self.assertEqual("server-upload", (target / "storage/upload").read_text())

    def remote(self, failure=""):
        # Run the actual SSH heredoc with server paths redirected and all privileged
        # commands mocked. No SSH connection or privileged command is executed.
        source = (ROOT / "deploy/deploy.sh").read_text()
        remote = source.split("<<'REMOTE'\n", 1)[1].split("\nREMOTE", 1)[0]
        app = self.work / "app"
        (app / "deploy").mkdir(parents=True)
        (app / "deploy/verify-ec2.sh").write_text('echo verify >> "$CALLS"\n')
        remote = remote.replace("APP=/var/www/university-bulletin-board", 'APP="' + app.as_posix() + '"')
        (self.work / "bulletin-board.tar.gz").write_text("mock archive")
        self.fake("flock", 'test "${FAILURE:-}" != lock')
        self.fake("tar", 'echo "tar $*" >> "$CALLS"; test "${FAILURE:-}" != archive')
        self.fake("sudo", '''echo "sudo $*" >> "$CALLS"
if [ "$1" = tar ] && [ "${FAILURE:-}" = backup ]; then exit 1; fi
if [ "$*" = "systemctl start bulletin-board-prepare" ] && [ "${FAILURE:-}" = prepare ]; then exit 1; fi
''')
        script = self.work / "remote.sh"
        script.write_text(remote, encoding="utf-8")
        result = self.run_bash(script, self.env | {"FAILURE": failure})
        return result, self.log.read_text() if self.log.exists() else ""

    def test_deployment_stops_backs_up_prepares_and_starts_in_order(self):
        result, calls = self.remote()
        self.assertEqual(0, result.returncode, result.stderr)
        steps = ["systemctl stop bulletin-board", "sudo tar -czf", "tar -xzf",
                 "sudo bash deploy/configure-ec2.sh", "systemctl start bulletin-board-prepare",
                 "systemctl start bulletin-board\n", "verify"]
        positions = [calls.index(step) for step in steps]
        self.assertEqual(sorted(positions), positions)

    def test_backup_failure_restores_old_service_without_extracting(self):
        result, calls = self.remote("backup")
        self.assertNotEqual(0, result.returncode)
        self.assertNotIn("tar -xzf", calls)
        self.assertIn("systemctl start bulletin-board\n", calls)

    def test_prepare_failure_keeps_changed_app_stopped(self):
        result, calls = self.remote("prepare")
        self.assertNotEqual(0, result.returncode)
        self.assertIn("tar -xzf", calls)
        self.assertNotIn("systemctl start bulletin-board\n", calls)
        self.assertTrue(calls.rstrip().endswith("systemctl stop bulletin-board"))

    def test_invalid_archive_does_not_stop_service(self):
        result, calls = self.remote("archive")
        self.assertNotEqual(0, result.returncode)
        self.assertNotIn("systemctl stop", calls)

    def test_concurrent_deployment_is_rejected_before_changes(self):
        result, calls = self.remote("lock")
        self.assertNotEqual(0, result.returncode)
        self.assertEqual("", calls)

    def test_prepare_stops_after_dependency_failure(self):
        app = self.work / "source"
        (app / "deploy").mkdir(parents=True)
        shutil.copy(ROOT / "deploy/prepare.sh", app / "deploy/prepare.sh")
        (app / ".ruby-version").write_text("4.0.2")
        self.fake("ruby", 'if [ "$1" = -e ]; then printf 4.0.2; fi')
        self.fake("bundle", 'echo "bundle $*" >> "$CALLS"; test "$1" != install')
        result = self.run_bash(app / "deploy/prepare.sh")
        self.assertNotEqual(0, result.returncode)
        self.assertNotIn("rails db:prepare", self.log.read_text())

    def test_prepare_accepts_repository_ruby_version_format(self):
        app = self.work / "source"
        (app / "deploy").mkdir(parents=True)
        shutil.copy(ROOT / "deploy/prepare.sh", app / "deploy/prepare.sh")
        shutil.copy(ROOT / ".ruby-version", app / ".ruby-version")
        self.fake("ruby", 'if [ "$1" = -e ]; then printf 4.0.2; fi')
        self.fake("bundle", 'echo "bundle $*" >> "$CALLS"')
        result = self.run_bash(app / "deploy/prepare.sh")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("rails db:prepare", self.log.read_text())
        self.assertIn("rails assets:precompile", self.log.read_text())

    def test_verification_requires_a_new_boot_when_previous_id_supplied(self):
        script = self.work / "verify.sh"
        boot = self.work / "boot-id"
        boot.write_text("new-boot\n")
        script.write_text((ROOT / "deploy/verify-ec2.sh").read_text().replace(
            "/proc/sys/kernel/random/boot_id", boot.as_posix()))
        self.fake("systemctl", 'echo "systemctl $*" >> "$CALLS"')
        self.fake("curl", 'echo health >> "$CALLS"')
        wrapper = self.work / "verify-wrapper.sh"
        wrapper.write_text('bash "' + script.as_posix() + '" new-boot\n')
        result = self.run_bash(wrapper)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("has not changed", result.stdout)
        wrapper.write_text('bash "' + script.as_posix() + '" old-boot\n')
        result = self.run_bash(wrapper)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("Boot ID: new-boot", result.stdout)
        self.assertIn("is-enabled --quiet bulletin-board", self.log.read_text())
        self.assertIn("is-enabled --quiet nginx", self.log.read_text())

    def test_configuring_existing_server_preserves_environment_and_nginx(self):
        etc = self.work / "etc"
        (etc / "nginx/sites-available").mkdir(parents=True)
        (etc / "nginx/sites-enabled").mkdir()
        (etc / "systemd/system").mkdir(parents=True)
        env_file = etc / "bulletin-board.env"
        env_file.write_text("SECRET_KEY_BASE=existing-private-test-value\n")
        nginx = etc / "nginx/sites-available/bulletin-board"
        nginx.write_text("existing customized HTTPS config")
        script = self.work / "configure.sh"
        text = (ROOT / "deploy/configure-ec2.sh").read_text()
        text = text.replace('if [ "$EUID" -ne 0 ]; then', 'if false; then')
        text = text.replace('/etc/', etc.as_posix() + '/')
        text = text.replace('/var/www/university-bulletin-board', (self.work / "app").as_posix())
        script.write_text(text)
        for name in ["install", "chown", "chmod", "systemctl", "nginx", "ln"]:
            self.fake(name, 'echo "' + name + ' $*" >> "$CALLS"')
        result = self.run_bash(script)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual("SECRET_KEY_BASE=existing-private-test-value\n", env_file.read_text())
        self.assertEqual("existing customized HTTPS config", nginx.read_text())
        self.assertNotIn("nginx-bulletin-board.conf", self.log.read_text())
        self.assertIn("enable bulletin-board nginx", self.log.read_text())
        self.assertNotIn("systemctl start bulletin-board", self.log.read_text())


if __name__ == "__main__":
    unittest.main()
