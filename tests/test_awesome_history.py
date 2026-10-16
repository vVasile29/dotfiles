"""History/graph checks; run in an existing Awesome session (no reload needed)."""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "awesome/.config/awesome/usage_history.lua"


class UsageHistory(unittest.TestCase):
    def check(self, code):
        script = f"""
local ok, err = pcall(function()
    local history = dofile({json.dumps(str(SOURCE))})
    {code}
end)
return ok and "HISTORY_TEST_PASS" or ("HISTORY_TEST_FAIL: " .. tostring(err))
"""
        result = subprocess.run(["awesome-client", script], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('string "HISTORY_TEST_PASS"', result.stdout, result.stdout + result.stderr)

    def test_downsampling_retains_full_span_and_weighted_average(self):
        self.check("""
local h, total = history.new(64), 0
for i = 1, 10000 do h:push(i % 101, i * 2); total = total + i % 101 end
assert(#h.values <= 64 and h.first_time == 2 and h.last_time == 20000)
assert(h.times[1] == 2 and h.times[#h.times] == 20000 and h.averaged)
local weight, sum = 0, 0
for i, value in ipairs(h.values) do
    weight = weight + h.weights[i]; sum = sum + value * h.weights[i]
    if i > 1 then assert(h.times[i] > h.times[i - 1]) end
end
assert(weight == 10000 and math.abs(sum - total) < 0.000001)
""")

    def test_clamps_percentages_and_ignores_missing_values(self):
        self.check("""
local h = history.new(4)
h:push(-5, 1); h:push(105, 2); h:push(nil, 3); h:push(0/0, 4); h:push("bad", 5)
assert(#h.values == 2 and h.values[1] == 0 and h.values[2] == 100)
assert(not h:push(50, 1) and not h:push(50, math.huge))
""")

    def test_cache_roundtrip_and_new_boot_reset(self):
        approved_tmp = Path("/tmp/opencode")
        with tempfile.TemporaryDirectory(prefix="dotfiles-history-", dir=approved_tmp if approved_tmp.is_dir() else None) as temp:
            path = json.dumps(str(Path(temp) / "history.tsv"))
            self.check(f"""
local original = {{cpu = history.new(64), ram = history.new(64)}}
for i=1, 1000 do original.cpu:push(i % 101, i*2); original.ram:push(60, i*2) end
assert(history.save({path}, "boot-a", original))
local restored = history.load({path}, "boot-a", 64)
for _, metric in ipairs({{"cpu", "ram"}}) do
    local a, b = original[metric], restored[metric]
    assert(a.first_time == b.first_time and a.last_time == b.last_time and a.started_at == b.started_at)
    assert(#a.values == #b.values and b.averaged)
    for i, value in ipairs(a.values) do
        assert(value == b.values[i] and a.times[i] == b.times[i] and a.weights[i] == b.weights[i])
    end
end
local fresh = history.load({path}, "boot-b", 64)
assert(#fresh.cpu.values == 0 and #fresh.ram.values == 0)
""")

    def test_corrupt_cache_is_ignored_without_executing_it(self):
        approved_tmp = Path("/tmp/opencode")
        with tempfile.TemporaryDirectory(prefix="dotfiles-history-", dir=approved_tmp if approved_tmp.is_dir() else None) as temp:
            path = Path(temp) / "history.tsv"
            path.write_text("awesome-usage-v1\tboot-a\ncpu\tpoint\tnot-a-number\t50\t1\n")
            self.check(f"""
local fresh = history.load({json.dumps(str(path))}, "boot-a")
assert(#fresh.cpu.values == 0 and #fresh.ram.values == 0)
""")

    def test_empty_and_full_graphs_render(self):
        approved_tmp = Path("/tmp/opencode")
        with tempfile.TemporaryDirectory(prefix="dotfiles-history-", dir=approved_tmp if approved_tmp.is_dir() else None) as temp:
            path = str(Path(temp) / "graph.svg")
            self.check(f"""
local wibox = require("wibox")
local h = history.new(61)
local anchor = wibox.widget.textbox("test")
local view = history.attach(anchor, h, "CPU HISTORY", "#bd93f9")
view:update(nil, "#bd93f9", "Waiting for first sample")
view:show({{x = screen.primary.geometry.x + 100, y = screen.primary.geometry.y + 10,
    width = 120, height = 26}}, screen.primary)
view:hide()
wibox.widget.draw_to_svg_file(view.popup.widget, {json.dumps(path)}, 376, 280)
for i = 1, 61 do h:push(50 + 40 * math.sin(i / 4), i * 3600) end
view:update(50, "#ff79c6", "History drawing test")
wibox.widget.draw_to_svg_file(view.popup.widget, {json.dumps(path)}, 376, 280)
assert(not view.popup.visible)
""")
            self.assertIn("<svg", Path(path).read_text())


if __name__ == "__main__":
    unittest.main(verbosity=2)
