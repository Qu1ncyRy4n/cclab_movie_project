# %%
"""exp00 movie task: first-look PSTHs from the Kilosort output. A quick look, not an analysis.

A PSTH is the average firing rate of a unit around an event (here: a video segment starting).

HOW TO USE
  Set up once, in the repo folder:      uv sync
  In Zed: pick the kernel "cclab-movie (.venv)", then run the cells top to bottom.
    Change SESSION in the settings cell and re-run from "load the chosen session".
    Each figure has its own cell; they are independent once the session is loaded.
  As a script, every figure for every session:
                                        uv run python preprocessing/exp00_psth_explore.py
  Figures are also saved as PNG under <data folder>/_figures/exp00_psth/.

WHERE THE DATA IS
  The first folder that exists is used: $CCLAB_MOVIE_DATA, the lab sorting PC's
  D:\Quincy\data\neuropixel\venni (seen from WSL), then ~/dev/research/data/neuropixel/venni (Mac).
  It must hold one folder per session, laid out as on the sorting PC. Only these files are read (0.6 GB in all):
    <session>/movie/processed/kilosort4*/  spike_times.npy  spike_clusters.npy  templates.npy
                                           channel_positions.npy  channel_map.npy  cluster_KSLabel.tsv
    <session>/movie/raw/<run>_g0/<run>_g0_imecN/*.ap.meta
    <session>/movie/processed/events/segments_exp00.csv   (written on first run; building it needs the
                                           nidq.bin/.meta and the task's event_log.csv + session_plan.csv)
  Getting them to the Mac: README.md in this folder. Timing caveats in full: timing.md.

What a trial looks like (about 15 s):  grey | A1 B1 A2 B2 A3 B3 | grey, reward
  two videos (A, B), each cut into three 2 s segments, shown alternately.
  Between segments there is a gap of about 0.5 s (0.2 to 1.5 s) while the next video is cued up;
  from the task code the last frame stays frozen on screen during it. Only A1 follows a grey screen.
  Trial types: NN (two nature videos), SS (two social), NS (one of each, either order).

Caveats to say out loud when showing these:
  * Units are Kilosort's automatic "good" label. Nothing has been curated in Phy.
  * Which block of sites is ACC and which is SEF on 10-09 / 10-10 / 10-11 is NOT confirmed;
    blocks are labelled by distance from the probe tip.
  * Time 0 is the TTL pulse, sent right after the first frame was handed to the graphics
    card. There is no photodiode, so the true light-on time is later by an unknown,
    roughly constant 1-3 frames (tens of ms). Latencies read off these plots are too short
    by that much; differences between conditions are not affected.
  * Task clock -> probe clock: the 1 Hz sync wave was off on 10-09 / 10-10 / 10-11, so events
    are placed by assuming the NI file and the probe file start and stop together.
    Checked on 10-12 (sync wave on): error under 1 ms. (The file headers' start sample and
    rate give 5-8 ms error on the same test.)
  * Eye position is ignored. SEF and FEF are eye-movement areas; anything here can be
    a gaze effect as much as a visual one.
"""

from __future__ import annotations

import os
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy.ndimage import gaussian_filter1d
from scipy.stats import wilcoxon

# %% settings: change these and re-run the cells below
_places = [os.environ.get("CCLAB_MOVIE_DATA", ""), "/mnt/d/Quincy/data/neuropixel/venni", "~/dev/research/data/neuropixel/venni"]
DATA = next((Path(p).expanduser() for p in _places if p and Path(p).expanduser().is_dir()), None)  # one folder per session
if DATA is None:
    raise SystemExit(f"error: no data folder found; set CCLAB_MOVIE_DATA or create one of {_places[1:]}")
OUT = DATA / "_figures" / "exp00_psth"  # figures are saved here

SESSION = "venni_20261012_SEF_FEF"  # any key of AREAS below

MIN_RATE = 0.5  # Hz; units firing less than this over the session are left out
BIT_ON, BIT_OFF = 2, 0  # NI digital lines: segment on, segment off (rig wiring)
REFERENCE_CHANNEL = 191  # NP1032 reference site, kept in the sort on purpose; its units are not neurons

# Which sorted units belong to which group of recording sites: (label, from um, to um above the tip).
# 10-12 has one probe per area. The single-probe sessions span two areas; which is which is unconfirmed.
AREAS = {
    "venni_20261009_SEF": {"kilosort4": [("lower half 0-3.8 mm", 0, 3840), ("upper half 3.8-7.7 mm", 3840, 7700)]},
    "venni_20261010_SEF": {"kilosort4": [("lower block 0-3.8 mm", 0, 3840), ("upper block 7.7-11.5 mm", 7600, 11600)]},
    "venni_20261011_SEF": {"kilosort4": [("lower block 0-3.8 mm", 0, 3840), ("upper block 7.7-11.5 mm", 7600, 11600)]},
    "venni_20261012_SEF_FEF": {"kilosort4_imec0": [("FEF", 0, 4000)], "kilosort4_imec1": [("SEF", 0, 4000)]},
}

# align: "segment" = every segment onset, "trial" = first segment onset of each trial.
# column: the column of the segment table that splits the events into lines.
VIEWS = {
    "category": dict(title="segment onset, by video category", align="segment", column="category",
                     pre=0.5, post=2.5, bin=0.01, smooth=0.02),
    "onset": dict(title="segment onset, trial start vs later segments", align="segment", column="onset",
                  pre=0.5, post=2.5, bin=0.01, smooth=0.02),
    "segment": dict(title="segment onset, by segment number in the trial", align="segment", column="segment",
                    pre=0.5, post=2.5, bin=0.01, smooth=0.02),
    "trial": dict(title="whole trial, by trial type", align="trial", column="condition",
                  pre=2.0, post=19.0, bin=0.05, smooth=0.05),
}  # fmt: skip
COLORS = {
    "social": "#D55E00", "nature": "#009E73",
    "trial start (after grey)": "#0072B2", "later (after frozen frame)": "#E69F00",
    "1": "#0072B2", "2": "#CC79A7", "3": "#E69F00",
    "NN": "#009E73", "SS": "#D55E00", "NS": "#7570B3",
}  # fmt: skip


# %% loading: task events
def read_meta(path: Path) -> dict[str, str]:
    """SpikeGLX .meta file -> dict of strings."""
    return dict(line.split("=", 1) for line in path.read_text().splitlines() if "=" in line)


def one(paths) -> Path:
    hits = sorted(paths)
    if len(hits) != 1:
        raise SystemExit(f"error: expected exactly one match, found {len(hits)}: {hits}")
    return hits[0]


def rising_edges(word: np.ndarray, bit: int) -> np.ndarray:
    b = (word >> bit) & 1
    return np.flatnonzero((b[:-1] == 0) & (b[1:] == 1)) + 1


def load_segments(session: str) -> pd.DataFrame:
    """One row per movie segment: what was shown, and when (as a fraction of the recording).

    The task sends no codes, only a pulse at segment on and one at segment off, so the k-th
    pulse is matched to the k-th SegmentOn row of the task's log. Counts must match exactly.
    """
    raw = DATA / session / "movie" / "raw"
    cache = DATA / session / "movie" / "processed" / "events" / "segments_exp00.csv"
    if cache.exists():
        return pd.read_csv(cache)
    run = one(raw.glob("*_g0"))
    task = one(raw.glob("*_exp/experiment/Output_exp00_pilot/*"))
    ni = read_meta(one(run.glob("*.nidq.meta")))
    word = np.memmap(one(run.glob("*.nidq.bin")), dtype=np.int16, mode="r")
    word = np.asarray(word.reshape(-1, int(ni["nSavedChans"]))[:, -1]).astype(np.uint16)  # last column = digital lines
    on, off = rising_edges(word, BIT_ON), rising_edges(word, BIT_OFF)

    log = pd.read_csv(task / "event_log.csv")
    seg = log[log.event == "SegmentOn"].reset_index(drop=True)
    if not (len(on) == len(off) == len(seg)):
        raise SystemExit(f"error: {session}: {len(on)} on pulses, {len(off)} off pulses, {len(seg)} SegmentOn rows")
    plan = pd.read_csv(task / "session_plan.csv").set_index("TrialNum").loc[seg.trial.astype(int)]
    is_a = seg.detail.str.contains("movie=A").to_numpy()
    df = pd.DataFrame(
        {
            "trial": seg.trial.astype(int),
            "segment": seg.segment.astype(int),
            "movie": np.where(is_a, "A", "B"),
            "onset": np.where(is_a & (seg.segment == 1), "trial start (after grey)", "later (after frozen frame)"),
            "video": np.where(is_a, plan.VideoA, plan.VideoB),
            "category": np.where(is_a, plan.CategoryA, plan.CategoryB),
            "condition": plan.Condition.to_numpy(),
            "t_on_s": on / float(ni["niSampRate"]),  # seconds from the start of the NI file, NI clock
            "t_off_s": off / float(ni["niSampRate"]),
            "on_frac": on / len(word),  # position in the recording, 0..1; see the clock caveat at the top
            "off_frac": off / len(word),
        }
    )
    cache.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(cache, index=False)
    return df


# %% loading: sorted units
def load_areas(session: str) -> list[dict]:
    """One dict per group of sites: its spikes (time-sorted, in probe samples) and a table of its units."""
    raw = DATA / session / "movie" / "raw"
    areas = []
    for ks_name, blocks in AREAS[session].items():
        ks = DATA / session / "movie" / "processed" / ks_name
        probe = ks_name.split("_")[-1] if "imec" in ks_name else "imec0"
        ap = read_meta(one(raw.glob(f"*_g0/*_{probe}/*.ap.meta")))
        fs = float(ap["imSampRate"])  # exact rate from the header; not the rounded one in params.py
        n_ap = int(ap["fileSizeBytes"]) // 2 // int(ap["nSavedChans"])  # samples in the recording

        st = np.load(ks / "spike_times.npy").ravel().astype(np.int64)  # sample number of every spike
        sc = np.load(ks / "spike_clusters.npy").ravel().astype(np.int64)  # which unit fired it
        templates = np.load(ks / "templates.npy")  # unit x time x channel: each unit's average waveform
        peak = np.abs(templates).max(1).argmax(1)  # channel where each unit is largest
        assert sc.max() < len(peak), "cluster ids no longer match templates (edited in Phy?)"
        depth = np.load(ks / "channel_positions.npy")[peak, 1]  # um above the probe tip
        channel = np.load(ks / "channel_map.npy").ravel()[peak]
        rate = np.bincount(sc, minlength=len(peak)) / (n_ap / fs)
        label = pd.read_csv(ks / "cluster_KSLabel.tsv", sep="\t").set_index("cluster_id").KSLabel
        good = (label.reindex(np.arange(len(peak))) == "good").to_numpy()

        for name, y0, y1 in blocks:
            keep = good & (depth >= y0) & (depth < y1) & (rate >= MIN_RATE) & (channel != REFERENCE_CHANNEL)
            ids = np.flatnonzero(keep)
            row = np.full(len(peak), -1)
            row[ids] = np.arange(len(ids))
            mine = row[sc] >= 0
            order = np.argsort(st[mine], kind="stable")
            areas.append(
                dict(
                    session=session, name=name, fs=fs, n_ap=n_ap,
                    st=st[mine][order], unit=row[sc[mine]][order],
                    units=pd.DataFrame({"cluster_id": ids, "depth_um": depth[ids], "rate_hz": rate[ids]}),
                )  # fmt: skip
            )
    return areas


_cache: dict[str, tuple[pd.DataFrame, list[dict]]] = {}


def load(session: str) -> tuple[pd.DataFrame, list[dict]]:
    if session not in _cache:
        _cache[session] = (load_segments(session), load_areas(session))
    return _cache[session]


# %% the PSTH itself
def event_groups(seg: pd.DataFrame, view: dict) -> dict[str, np.ndarray]:
    """Split events into the lines of a view. Returns {line name: positions in the recording (0..1)}."""
    if view["align"] == "trial":
        full = seg.groupby("trial").filter(lambda g: len(g) == 6)  # complete trials only
        seg = full.groupby("trial").first().reset_index()  # first segment of each trial
    return {str(k): g.on_frac.to_numpy() for k, g in seg.groupby(view["column"])}


def psth(area: dict, on_frac: np.ndarray, pre: float, post: float, bin_s: float) -> np.ndarray:
    """Average firing rate around the events, in Hz: one row per unit, one column per time bin."""
    fs, st, unit, n_units = area["fs"], area["st"], area["unit"], len(area["units"])
    n_bins = int(round((pre + post) / bin_s))
    events = on_frac * area["n_ap"]  # event times in probe samples
    lo = np.searchsorted(st, events - pre * fs)
    hi = np.searchsorted(st, events + post * fs)
    flat = []
    for e, a, b in zip(events, lo, hi):  # spikes st[a:b] fall inside this event's window
        k = np.floor(((st[a:b] - e) / fs + pre) / bin_s).astype(np.int64).clip(0, n_bins - 1)
        flat.append(unit[a:b] * n_bins + k)
    counts = np.bincount(np.concatenate(flat), minlength=n_units * n_bins).reshape(n_units, n_bins)
    return counts / len(events) / bin_s


def window_counts(area: dict, on_frac: np.ndarray, t0: float, t1: float) -> np.ndarray:
    """Spike count of every unit in [t0, t1) seconds around every event: events x units."""
    fs, st, unit, n_units = area["fs"], area["st"], area["unit"], len(area["units"])
    events = on_frac * area["n_ap"]
    lo = np.searchsorted(st, events + t0 * fs)
    hi = np.searchsorted(st, events + t1 * fs)
    return np.array([np.bincount(unit[a:b], minlength=n_units) for a, b in zip(lo, hi)])


def compute(area: dict, seg: pd.DataFrame, view: dict) -> tuple[np.ndarray, dict[str, np.ndarray], dict[str, int]]:
    """Time axis, {line name: smoothed rate, units x bins}, {line name: number of events}."""
    t = np.arange(-view["pre"], view["post"], view["bin"])[: int(round((view["pre"] + view["post"]) / view["bin"]))]
    t = t + view["bin"] / 2
    groups = event_groups(seg, view)
    rates = {
        k: gaussian_filter1d(psth(area, ev, view["pre"], view["post"], view["bin"]), view["smooth"] / view["bin"], axis=1)
        for k, ev in groups.items()
    }
    return t, rates, {k: len(ev) for k, ev in groups.items()}


def responsiveness(area: dict, seg: pd.DataFrame) -> pd.DataFrame:
    """Per unit: rate 50-350 ms after the first segment of a trial vs the 300 ms of blank screen before it."""
    first = seg[(seg.segment == 1) & (seg.movie == "A")].on_frac.to_numpy()
    before = window_counts(area, first, -0.35, -0.05) / 0.3
    after = window_counts(area, first, 0.05, 0.35) / 0.3
    p = np.array([wilcoxon(a, b).pvalue if np.any(a != b) else 1.0 for a, b in zip(after.T, before.T)])
    return area["units"].assign(before_hz=before.mean(0), after_hz=after.mean(0), p=p)


def trial_layout(seg: pd.DataFrame) -> list[tuple[str, float, float]]:
    """Median on/off time of the six segments relative to the start of the trial (for shading)."""
    full = seg.groupby("trial").filter(lambda g: len(g) == 6).copy()
    t0 = full.groupby("trial").t_on_s.transform("first")
    full["on"], full["off"] = full.t_on_s - t0, full.t_off_s - t0
    med = full.groupby(["segment", "movie"])[["on", "off"]].median().reset_index().sort_values("on")
    return [(f"{r.movie}{r.segment}", r.on, r.off) for r in med.itertuples()]


def shade(ax, seg: pd.DataFrame, view: dict) -> None:
    """Mark when a video is on screen."""
    if view["align"] == "trial":
        for name, on, off in trial_layout(seg):
            ax.axvspan(on, off, color="#0072B2" if name[0] == "A" else "#E69F00", alpha=0.10, lw=0)
            ax.text((on + off) / 2, 1.0, name, transform=ax.get_xaxis_transform(), ha="center", va="bottom", fontsize=8)
    else:
        ax.axvspan(0, 2.0, color="0.5", alpha=0.10, lw=0)
    ax.axvline(0, color="k", lw=0.6)


# %% load the chosen session and print what is in it
seg, areas = load(SESSION)
print(f"{SESSION}: {len(seg)} segments in {seg.trial.nunique()} trials")
print(seg.groupby(["condition", "category"]).size().unstack(fill_value=0).to_string())
for area in areas:
    r = responsiveness(area, seg)
    up, down = ((r.p < 0.01) & (r.after_hz > r.before_hz)).sum(), ((r.p < 0.01) & (r.after_hz < r.before_hz)).sum()
    print(f"  {area['name']:<24} {len(r):>4} good units; at trial start {up} fire more, {down} fire less (p < 0.01, uncorrected)")


# %% the two figure types (run this cell once; the figure cells below call them)
def figure_population(session: str, view_name: str) -> plt.Figure:
    seg, areas = load(session)
    view = VIEWS[view_name]
    fig, axes = plt.subplots(len(areas), 2, figsize=(13, 4.2 * len(areas)), squeeze=False)
    for (ax, hm), area in zip(axes, areas):
        t, rates, n = compute(area, seg, view)
        pooled = sum(r * n[k] for k, r in rates.items()) / sum(n.values())  # all events together
        base_rate = pooled[:, t < 0].mean(1, keepdims=True)
        for k, r in rates.items():
            r = r - base_rate  # each unit as a change from its own rate before the event
            m, sem = r.mean(0), r.std(0) / np.sqrt(len(r))
            ax.fill_between(t, m - sem, m + sem, color=COLORS[k], alpha=0.2, lw=0)
            ax.plot(t, m, color=COLORS[k], lw=1.5, label=f"{k} (n={n[k]})")
        shade(ax, seg, view)
        ax.set(xlim=(t[0], t[-1]), xlabel="time from TTL (s)", ylabel="change in rate, mean of units (Hz)")
        ax.set_title(f"{area['name']}: {len(area['units'])} good units", loc="left", pad=14)
        ax.legend(frameon=False, fontsize=8, loc="upper right")

        # every unit, all events pooled, as a z-score against the time before the event
        base = pooled[:, t < 0]
        z = (pooled - base.mean(1, keepdims=True)) / (base.std(1, keepdims=True) + 0.5)
        early = z[:, (t > 0.05) & (t < 0.5)].mean(1)
        im = hm.imshow(z[np.argsort(-early)], aspect="auto", cmap="RdBu_r", vmin=-6, vmax=6,
                       extent=(t[0], t[-1], len(z), 0), interpolation="nearest")  # fmt: skip
        hm.axvline(0, color="k", lw=0.6)
        hm.set(xlabel="time from TTL (s)", ylabel="units, strongest early response on top")
        hm.set_title("each unit, all events pooled", loc="left", pad=14)
        fig.colorbar(im, ax=hm, label="z vs before the event")
    fig.suptitle(f"{session}   |   {view['title']}   |   Kilosort 'good' units, uncurated", fontsize=11)
    fig.tight_layout()
    OUT.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT / f"{session}_{view_name}_population.png", dpi=130)
    return fig



def figure_unit(session: str, area_index: int, view_name: str, unit: int | None = None) -> plt.Figure:
    seg, areas = load(session)
    area, view = areas[area_index], VIEWS[view_name]
    if unit is None:
        unit = int(responsiveness(area, seg).p.argmin())
    info = area["units"].iloc[unit]
    spikes = area["st"][area["unit"] == unit]
    t, rates, n = compute(area, seg, view)

    fig, (ra, ax) = plt.subplots(2, 1, figsize=(9, 7), sharex=True, height_ratios=[2, 1])
    row = 0
    for k, ev in event_groups(seg, view).items():
        ev = ev * area["n_ap"]
        lo, hi = np.searchsorted(spikes, ev - view["pre"] * area["fs"]), np.searchsorted(spikes, ev + view["post"] * area["fs"])
        x = np.concatenate([(spikes[a:b] - e) / area["fs"] for e, a, b in zip(ev, lo, hi)])
        y = np.concatenate([np.full(b - a, row + i) for i, (a, b) in enumerate(zip(lo, hi))])
        ra.plot(x, y, "|", color=COLORS[k], ms=2.5, mew=0.6)
        row += len(ev)
        ax.plot(t, rates[k][unit], color=COLORS[k], lw=1.5, label=f"{k} (n={n[k]})")
    for a in (ra, ax):
        shade(a, seg, view)
    ra.set(ylabel="event (grouped by line colour)", ylim=(row, 0))
    ax.set(xlim=(t[0], t[-1]), xlabel="time from TTL (s)", ylabel="rate (Hz)")
    ax.legend(frameon=False, fontsize=8, loc="upper right")
    fig.suptitle(
        f"{session} | {area['name']} | unit {int(info.cluster_id)} at {info.depth_um:.0f} um, "
        f"{info.rate_hz:.1f} Hz | {view['title']}",
        fontsize=10,
    )
    fig.tight_layout()
    OUT.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT / f"{session}_{area['name'].split()[0]}_unit{int(info.cluster_id)}_{view_name}.png", dpi=130)
    return fig


# %% figure: social vs nature segments
figure_population(SESSION, "category")
plt.show()

# %% figure: first segment of a trial (after a grey screen) vs later segments
figure_population(SESSION, "onset")
plt.show()

# %% figure: segment 1 vs 2 vs 3 of the trial
figure_population(SESSION, "segment")
plt.show()

# %% figure: the whole trial, by trial type (NN / SS / NS)
figure_population(SESSION, "trial")
plt.show()

# %% figure: one unit, every event as a row of spikes (a raster)
AREA = 0  # which group of sites: 0 = the first one printed by the "load" cell
UNIT = None  # row number in that area's unit table (areas[AREA]["units"]), or None for the most responsive unit
figure_unit(SESSION, AREA, "category", UNIT)  # any view works here: category | onset | segment | trial
plt.show()

# %% timing check: what the pulses say about the task's own timing
d = seg.sort_values("t_on_s").reset_index(drop=True)
gap = d.t_on_s.shift(-1) - d.t_off_s  # from one segment's off pulse to the next segment's on pulse
same_trial = d.trial.shift(-1) == d.trial
ms = lambda s: f"median {s.median() * 1e3:6.0f} ms, range {s.min() * 1e3:6.0f} to {s.max() * 1e3:6.0f} ms"  # noqa: E731
print("segment length        ", ms(d.t_off_s - d.t_on_s))
print("A off -> B on          ", ms(gap[same_trial & (d.movie == "A")]))
print("B off -> next A on     ", ms(gap[same_trial & (d.movie == "B")]))


# %% when run as a script: save the figures for every session
if __name__ == "__main__" and "get_ipython" not in globals():
    for s in AREAS:
        for v in VIEWS:
            figure_population(s, v)
            plt.close("all")
        figure_unit(s, 0, "category")
        plt.close("all")
    print("figures:", OUT)
