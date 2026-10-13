from conftest import T0, iso, sample_row, seconds, write_csv

from onq_validation import radio
from onq_validation.io import read_csv
from onq_validation.profiles import PROFILES


def _ref_rows(tmp_path, values, shift=0.3, pci="101"):
    rows = [
        [iso(T0 + seconds(i + shift)), rsrp, rsrq, 11.0, pci, "LTE"]
        for i, (rsrp, rsrq) in enumerate(values)
    ]
    path = write_csv(
        tmp_path / "ref.csv",
        ["timestamp", "rsrp_dbm", "rsrq_db", "sinr_db", "pci", "network_type"],
        rows,
    )
    return radio.load_reference(read_csv(path), PROFILES["generic"])


def test_agreement_within_two_db_passes(tmp_path, samples_csv):
    onq = read_csv(samples_csv([sample_row(i, T0 + seconds(i), rsrp=-90 - i) for i in range(10)]))
    ref = _ref_rows(tmp_path, [(-91 - i, -11.5) for i in range(10)])
    r = radio.compare(onq, ref)
    assert r.matched == 10
    rsrp, rsrq, sinr = r.metrics
    assert rsrp.median_abs_diff == 1.0
    assert rsrp.mean_bias == 1.0
    assert rsrq.median_abs_diff == 1.5
    assert sinr.passed is None
    assert r.pci_agreement == 1.0
    assert r.passed


def test_large_offset_fails(tmp_path, samples_csv):
    onq = read_csv(samples_csv([sample_row(i, T0 + seconds(i)) for i in range(5)]))
    ref = _ref_rows(tmp_path, [(-95.0, -10.0)] * 5, pci="202")
    r = radio.compare(onq, ref)
    assert r.metrics[0].median_abs_diff == 5.0
    assert not r.passed
    assert r.pci_agreement == 0.0


def test_tolerance_offset_and_non_lte(tmp_path, samples_csv):
    rows = [sample_row(i, T0 + seconds(i)) for i in range(4)]
    rows.append(sample_row(9, T0 + seconds(1), rat="NR"))
    onq = read_csv(samples_csv(rows))
    ref = _ref_rows(tmp_path, [(-90.0, -10.0)] * 4, shift=10.0)
    assert radio.compare(onq, ref).matched == 0
    shifted = radio.compare(onq, ref, offset_s=10.0)
    assert shifted.lte_samples == 4
    assert shifted.matched == 4


def test_no_pairs_is_not_a_pass(tmp_path, samples_csv):
    onq = read_csv(samples_csv([sample_row(0, T0, rsrp=None, rsrq=None)]))
    r = radio.compare(onq, _ref_rows(tmp_path, [(-90.0, -10.0)]))
    assert r.metrics[0].median_abs_diff is None
    assert not r.passed


def test_gnettrack_profile(tmp_path):
    path = write_csv(
        tmp_path / "g.csv",
        ["Timestamp", "Level", "Qual", "SNR", "NetworkTech"],
        [["2026.10.13_11.00.00", -97, -12, 5, "LTE"], ["bad", -1, -1, 1, "LTE"]],
    )
    ref = radio.load_reference(read_csv(path), PROFILES["gnettrack"], utc_offset_h=10)
    assert len(ref) == 1
    assert ref[0].time == T0
    assert ref[0].values["rsrp"] == -97
    assert ref[0].pci is None
