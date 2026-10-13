from conftest import T0, iso, sample_row, seconds, write_csv

from onq_validation import sampling, throughput
from onq_validation.io import read_csv

TEST_HEADER = ["test_type", "timestamp", "status", "dl_mean_mbps", "ul_mean_mbps"]


def _pairs(tmp_path, n, factor=1.04):
    onq = [["speed", iso(T0 + seconds(600 * i)), "ok", 50 * factor, 10 * factor] for i in range(n)]
    onq.append(["latency", iso(T0), "ok", None, None])
    onq.append(["speed", iso(T0), "failed", None, None])
    ref = [[iso(T0 + seconds(600 * i + 60)), 50, 10] for i in range(n)]
    o = read_csv(write_csv(tmp_path / "t.csv", TEST_HEADER, onq))
    r = throughput.load_reference(
        read_csv(write_csv(tmp_path / "r.csv", ["timestamp", "dl_mbps", "ul_mbps"], ref))
    )
    return o, r


def test_thirty_pairs_within_ten_percent_pass(tmp_path):
    onq, ref = _pairs(tmp_path, 30)
    r = throughput.compare(onq, ref)
    assert r.onq_tests == 30
    assert r.matched == 30
    assert round(r.directions[0].median_abs_rel_diff, 3) == 0.04
    assert r.passed


def test_too_few_or_too_far_fails(tmp_path):
    onq, ref = _pairs(tmp_path, 29)
    assert not throughput.compare(onq, ref).passed
    onq, ref = _pairs(tmp_path, 30, factor=1.2)
    assert not throughput.compare(onq, ref).passed
    onq, ref = _pairs(tmp_path, 30)
    assert throughput.compare(onq, ref, window_s=10).matched == 0


def test_two_hours_complete_passes(samples_csv):
    rows = [sample_row(i, T0 + seconds(i)) for i in range(7201) if not 100 <= i < 130]
    r = sampling.analyse(read_csv(samples_csv(rows)), battery_start=100, battery_end=76)
    assert round(r.duration_h, 3) == 2.0
    assert r.expected == 7201
    assert round(r.missing_pct, 2) == 0.42
    assert len(r.gaps) == 1 and r.gaps[0].seconds == 31
    assert r.sampling_passed
    assert r.battery_drain_pct_per_h == 12
    assert r.battery_passed


def test_short_or_lossy_fails(samples_csv):
    short = sampling.analyse(
        read_csv(samples_csv([sample_row(i, T0 + seconds(i)) for i in range(60)]))
    )
    assert not short.sampling_passed
    assert short.battery_passed is None
    lossy_rows = [sample_row(i, T0 + seconds(2 * i), fix=i % 2 == 0) for i in range(3601)]
    lossy = sampling.analyse(read_csv(samples_csv(lossy_rows)))
    assert lossy.missing_pct > 49
    assert lossy.fix_pct > 49
    assert not lossy.sampling_passed
    one = sampling.analyse(read_csv(samples_csv([sample_row(0, T0)])))
    assert one.samples == 1 and one.duration_h == 0
