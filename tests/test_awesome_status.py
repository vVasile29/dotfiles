"""Sampler checks in an existing Awesome session; no reload or network changes."""

import json
from pathlib import Path
import subprocess
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "awesome/.config/awesome/status.lua"


class StatusSampler(unittest.TestCase):
    def check(self, assertions):
        script = f"""
local ok, err = pcall(function()
    local file = assert(io.open({json.dumps(str(SOURCE))}))
    local source = file:read("*a")
    file:close()
    -- Run the actual sampler with fixtures, without starting timers, audio or UI.
    local block = assert(source:match("(local function numbers.-)local function refresh_views"))
    local files = {{
        ["/proc/stat"] = "cpu 100 0 50 850 0 0 0 0\\n",
        ["/proc/loadavg"] = "0.10 0.20 0.30 1/100 1\\n",
        ["/proc/meminfo"] = "MemTotal: 1000 kB\\nMemAvailable: 600 kB\\n",
        ["/proc/uptime"] = "100.0 200.0\\n",
        ["/proc/net/route"] = "Iface Destination Gateway Flags RefCnt Use Metric Mask MTU Window IRTT\\n",
        ["/proc/net/ipv6_route"] = "",
    }}
    local function counters(rx, tx)
        files["/proc/net/dev"] = "Inter-| Receive | Transmit\\n"
            .. " face |bytes packets errs drop fifo frame compressed multicast|bytes packets errs drop fifo colls carrier compressed\\n"
            .. " lo: 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0\\n"
            .. " test0: " .. rx .. " 1 0 0 0 0 0 0 " .. tx .. " 1 0 0 0 0 0 0\\n"
    end
    counters(100, 200)
    local ipv4 = "test0 00000000 0100000A 0003 0 0 100 00000000 0 0 0\\n"
    local ipv6 = string.rep("0", 32) .. " 00 " .. string.rep("0", 32)
        .. " 00 " .. string.rep("0", 32) .. " 00000064 00000000 00000000 00000003 test0\\n"
    local now = 1
    local env = setmetatable({{
        read = function(path) return assert(files[path], path) end,
        state = {{}}, last_saved = math.huge,
        status = {{ history = {{
            cpu = {{ push = function() end }}, ram = {{ push = function() end }},
        }} }},
        GLib = {{ get_monotonic_time = function() return now * 1000000 end }},
    }}, {{ __index = _G }})
    local sample = assert(load(block .. " return sample", "status-sampler-test", "t", env))()
    {assertions}
end)
return ok and "STATUS_TEST_PASS" or ("STATUS_TEST_FAIL: " .. tostring(err))
"""
        result = subprocess.run(["awesome-client", script], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('string "STATUS_TEST_PASS"', result.stdout, result.stdout + result.stderr)

    def test_offline_headers_do_not_crash_sampler(self):
        self.check("""
sample()
assert(env.state.interface == nil and env.state.down == 0 and env.state.up == 0)
files["/proc/stat"] = "cpu 110 0 50 940 0 0 0 0\\n"
now = 2
sample()
assert(math.abs(env.state.cpu - 10) < 0.000001 and env.state.ram == 40)
""")

    def test_ipv4_default_route_tracks_rates(self):
        self.check("""
files["/proc/net/route"] = ipv4
sample()
assert(env.state.interface == "test0")
now = 3
counters(2148, 1224)
sample()
assert(env.state.down == 1024 and env.state.up == 512)
""")

    def test_ipv6_only_default_route(self):
        self.check("""
files["/proc/net/ipv6_route"] = ipv6
sample()
assert(env.state.interface == "test0")
""")

    def test_disconnect_and_reconnect_reset_rates(self):
        self.check("""
files["/proc/net/route"] = ipv4
sample()
files["/proc/net/route"] = ""
now = 2
sample()
assert(env.state.interface == nil and env.state.down == 0 and env.state.up == 0)
files["/proc/net/route"] = ipv4
counters(10000, 20000)
now = 3
sample()
assert(env.state.interface == "test0" and env.state.down == 0 and env.state.up == 0)
counters(11024, 20512)
now = 4
sample()
assert(env.state.down == 1024 and env.state.up == 512)
""")


if __name__ == "__main__":
    unittest.main(verbosity=2)
