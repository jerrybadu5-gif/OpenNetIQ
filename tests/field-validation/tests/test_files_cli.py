import json

from conftest import SAMPLE_HEADER, T0, iso, sample_row, seconds, write_csv

from onq_validation import files
from onq_validation.cli import main

GOOD_GEOJSON = {
    "type": "FeatureCollection",
    "features": [
        {
            "type": "Feature",
            "geometry": {"type": "LineString", "coordinates": [[147.1, -9.4], [147.2, -9.5]]},
            "properties": {"feature_type": "track"},
        },
        {
            "type": "Feature",
            "geometry": {"type": "Point", "coordinates": [147.1, -9.4, 40]},
            "properties": {"feature_type": "sample"},
        },
        {"type": "Feature", "geometry": None, "properties": {"feature_type": "speed_test"}},
    ],
}


def test_good_exports(samples_csv, geojson):
    assert files.check_csv(samples_csv([sample_row(0, T0)])) == []
    assert files.check_geojson(geojson(GOOD_GEOJSON)) == []


def test_csv_problems(tmp_path):
    p = write_csv(tmp_path / "bad.csv", ["timestamp", "lat"], [["x", "null"], ["only"]])
    problems = files.check_csv(p)
    assert any("missing column measurement_id" in x for x in problems)
    assert any("literal 'null'" in x for x in problems)
    assert any("1 fields" in x for x in problems)
    empty = tmp_path / "empty.csv"
    empty.write_text("")
    assert files.check_csv(empty) == ["empty file"]
    dup = write_csv(tmp_path / "dup.csv", ["a", "a"], [])
    assert "duplicate column names" in files.check_csv(dup, required=())


def test_geojson_problems(geojson):
    swapped = {
        "type": "FeatureCollection",
        "features": [
            {
                "type": "Feature",
                "geometry": {"type": "Point", "coordinates": [-9.4, 147.1]},
                "properties": {"feature_type": "sample"},
            },
            {
                "type": "Feature",
                "geometry": {"type": "LineString", "coordinates": [[1, 1]]},
                "properties": {},
            },
            {
                "type": "Feature",
                "geometry": {"type": "Polygon", "coordinates": []},
                "properties": {"feature_type": "x"},
            },
            {
                "type": "Feature",
                "geometry": {"type": "Point", "coordinates": ["a", 1]},
                "properties": {"feature_type": "x"},
            },
            {
                "type": "Feature",
                "geometry": {"type": "Point", "coordinates": [1]},
                "properties": {"feature_type": "x"},
            },
            "nope",
        ],
    }
    problems = files.check_geojson(geojson(swapped))
    assert any("lat/lon swapped" in p for p in problems)
    assert any("LineString needs" in p for p in problems)
    assert any("no properties.feature_type" in p for p in problems)
    assert any("unexpected geometry" in p for p in problems)
    assert any("non-numeric" in p for p in problems)
    assert any("position must be" in p for p in problems)
    assert any("not a Feature" in p for p in problems)
    assert files.check_geojson(geojson("{oops"))[0].startswith("not valid JSON")
    assert files.check_geojson(geojson({"type": "Feature"})) == ["root is not a FeatureCollection"]


def test_cli_radio_pass_and_json(tmp_path, samples_csv, capsys):
    onq = samples_csv([sample_row(i, T0 + seconds(i)) for i in range(5)])
    ref = write_csv(
        tmp_path / "ref.csv",
        ["Timestamp", "Level", "Qual", "SNR", "NetworkTech"],
        [
            [(T0 + seconds(i)).strftime("%Y.%m.%d_%H.%M.%S"), -91, -10.5, 10, "LTE"]
            for i in range(5)
        ],
    )
    out = tmp_path / "radio.json"
    code = main(
        [
            "--json",
            str(out),
            "radio",
            "--onq",
            str(onq),
            "--ref",
            str(ref),
            "--profile",
            "gnettrack",
        ]
    )
    assert code == 0
    assert "Radio agreement: PASS" in capsys.readouterr().out
    data = json.loads(out.read_text())
    assert data["radio"]["passed"] is True
    assert data["radio"]["metrics"][0]["median_abs_diff"] == 1.0


def test_cli_other_commands(tmp_path, samples_csv, geojson, capsys):
    onq = samples_csv([sample_row(i, T0 + seconds(i)) for i in range(10)])
    assert (
        main(["sampling", "--onq", str(onq), "--battery-start", "90", "--battery-end", "89"]) == 1
    )
    assert "Sampling: FAIL" in capsys.readouterr().out
    assert main(["files", "--csv", str(onq), "--geojson", str(geojson(GOOD_GEOJSON))]) == 0
    assert "Export files: PASS" in capsys.readouterr().out
    tests = write_csv(
        tmp_path / "t.csv",
        ["test_type", "timestamp", "status", "dl_mean_mbps", "ul_mean_mbps"],
        [["speed", iso(T0), "ok", 50, 10]],
    )
    ref = write_csv(tmp_path / "r.csv", ["when", "dl", "ul"], [[iso(T0), 50, 10]])
    assert (
        main(
            [
                "throughput",
                "--onq",
                str(tests),
                "--ref",
                str(ref),
                "--map",
                "time=when",
                "--map",
                "dl=dl",
                "--map",
                "ul=ul",
            ]
        )
        == 1
    )  # n < 30
    assert "Throughput agreement: FAIL" in capsys.readouterr().out


def test_cli_bad_input(tmp_path, samples_csv, capsys):
    onq = samples_csv([sample_row(0, T0)])
    empty_ref = write_csv(tmp_path / "e.csv", ["timestamp"], [])
    assert main(["radio", "--onq", str(onq), "--ref", str(empty_ref)]) == 2
    assert main(["radio", "--onq", str(onq), "--ref", str(tmp_path / "missing.csv")]) == 2
    assert main(["radio", "--onq", str(onq), "--ref", str(empty_ref), "--map", "bad"]) == 2
    assert main(["files"]) == 2
    assert "onq-validate:" in capsys.readouterr().err


def test_header_matches_app_export():
    # Columns the checks read must exist in the app's samples export.
    app_columns = {
        "timestamp",
        "lat",
        "h_accuracy_m",
        "serving_rat",
        "serving_pci_psc_bsic",
        "serving_rsrp_dbm",
        "serving_rsrq_db",
        "serving_sinr_db",
    }
    assert app_columns <= set(SAMPLE_HEADER)


def test_help_renders_for_every_command(capsys):
    import pytest

    for argv in (
        ["--help"],
        ["radio", "-h"],
        ["throughput", "-h"],
        ["sampling", "-h"],
        ["files", "-h"],
    ):
        with pytest.raises(SystemExit) as exit_info:
            main(argv)
        assert exit_info.value.code == 0
    assert "onq-validate" in capsys.readouterr().out
