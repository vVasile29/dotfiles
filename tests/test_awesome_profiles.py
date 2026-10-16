"""Run with python3 tests/test_awesome_profiles.py in a running Awesome session.

Tests use temporary hardware/config fixtures; they do not reload Awesome or
modify the real selector, monitor layout, brightness, battery, or audio state.
"""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "awesome/.config/awesome"


class MachineProfiles(unittest.TestCase):
    def setUp(self):
        approved_tmp = Path("/tmp/opencode")
        self.temp = tempfile.TemporaryDirectory(
            prefix="dotfiles-profiles-", dir=approved_tmp if approved_tmp.is_dir() else None
        )
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "profiles").symlink_to(SOURCE / "profiles", target_is_directory=True)

    def write(self, path, text):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)

    def hardware(self):
        for name, kind, scope, present in [
            ("BAT1", "Battery", "System", "1"),
            ("mouse", "Battery", "Device", "1"),
            ("absent", "Battery", "System", "0"),
            ("ups", "UPS", "System", "1"),
        ]:
            base = f"sys/class/power_supply/{name}/"
            for key, value in {"type": kind, "scope": scope, "present": present, "capacity": "63"}.items():
                self.write(base + key, value + "\n")
        self.write("sys/class/power_supply/AC0/type", "Mains\n")
        self.write("sys/class/backlight/intel_backlight/max_brightness", "24000\n")
        self.write("sys/class/backlight/intel_backlight/brightness", "12000\n")
        self.write("sys/class/backlight/unusable/max_brightness", "0\n")
        self.write("sys/class/backlight/unusable/brightness", "0\n")

    def check(self, assertions, command_available=True):
        find = 'return "/test/bin/" .. program' if command_available else "return nil"
        code = f"""
local ok, err = pcall(function()
    local loader = dofile({json.dumps(str(SOURCE / 'machine_profile.lua'))})
    local p = loader.load {{
        config_dir = {json.dumps(str(self.root))},
        sys_root = {json.dumps(str(self.root / 'sys'))},
        home = "/home/test",
        find_program = function(program) {find} end,
    }}
    {assertions}
end)
return ok and "PROFILE_TEST_PASS" or ("PROFILE_TEST_FAIL: " .. tostring(err))
"""
        result = subprocess.run(["awesome-client", code], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('string "PROFILE_TEST_PASS"', result.stdout, result.stdout + result.stderr)

    def test_desktop_ignores_laptop_hardware(self):
        self.hardware()
        self.write("machine.lua", 'return { profile = "desktop" }')
        self.check("""
assert(p.selected and p.name == "desktop" and not p.error)
assert(not p.battery and not p.brightness)
assert(p.monitor_script == "/home/test/scripts/set_monitors.sh")
assert(#p.app_rules == 5 and p.compositor)
""")

    def test_laptop_detects_adapters_and_excludes_peripherals(self):
        self.hardware()
        self.write("machine.lua", 'return { profile = "laptop" }')
        self.check("""
assert(p.selected and p.name == "laptop" and not p.error)
assert(p.battery and p.brightness)
assert(#p.hardware.batteries == 1 and p.hardware.batteries[1] == "BAT1")
assert(p.hardware.ac == "AC0" and p.hardware.backlight == "intel_backlight")
assert(#p.hardware.backlights == 1)
assert(not p.monitor_script and #p.app_rules == 0 and not p.compositor)
""")

    def test_laptop_without_hardware(self):
        self.write("machine.lua", 'return { profile = "laptop" }')
        self.check("""
assert(p.name == "laptop" and not p.battery and not p.brightness)
assert(not p.monitor_script and #p.app_rules == 0)
""")

    def test_missing_brightnessctl(self):
        self.hardware()
        self.write("machine.lua", 'return { profile = "laptop" }')
        self.check("assert(p.battery and not p.brightness)", command_available=False)

    def test_missing_selector_is_safe(self):
        self.hardware()
        self.check("""
assert(not p.selected and not p.error)
assert(not p.battery and not p.brightness and not p.monitor_script)
assert(#p.app_rules == 0 and not p.compositor)
""")

    def test_invalid_selectors_fall_back_safely(self):
        for selector in [
            'return { profile = "laptop"',
            'return { profile = "../other" }',
            'return "laptop"',
            'return { profile = "laptop", brightness = "yes" }',
            'return { profile = "laptop", unknown = true }',
            'return { profile = "desktop", app_rules = { false } }',
        ]:
            with self.subTest(selector=selector):
                self.write("machine.lua", selector)
                self.check("""
assert(not p.selected and p.error)
assert(not p.battery and not p.brightness and not p.monitor_script)
assert(#p.app_rules == 0 and not p.compositor)
""")

    def test_explicit_false_overrides_are_preserved(self):
        self.hardware()
        self.write("machine.lua", """
return { profile = "laptop", battery = false, brightness = false,
    compositor = true, monitor_script = false, app_rules = {} }
""")
        self.check("assert(not p.battery and not p.brightness and p.compositor and not p.monitor_script)")

    def test_monitor_paths_and_rule_replacement(self):
        for path in ["scripts/custom.sh", "~/scripts/custom.sh", "/home/test/scripts/custom.sh"]:
            with self.subTest(path=path):
                self.write("machine.lua", 'return { profile = "desktop", app_rules = {}, monitor_script = '
                           + json.dumps(path) + " }")
                self.check('assert(#p.app_rules == 0 and p.monitor_script == "/home/test/scripts/custom.sh")')


if __name__ == "__main__":
    unittest.main(verbosity=2)
