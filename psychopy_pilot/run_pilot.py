"""RUN_exp00_pilot, PsychoPy version.

Same design as Code/exp00_pilot_interleave/RUN_exp00_pilot.m, built in
parallel as a stack comparison — not a replacement. Per trial:

  a. fixation dot, hold config.t_hold_fixation (0.85s default) to proceed
  b. pick 2 DISTINCT videos at random from the 4-video pool
     (video_ebm_dataset/pilot_pool.csv), interleave A/B/A/B... at
     config.seg_dur seconds each, config.per_clip_seconds of each clip
     total, from t=0
  c. unconditional reward (on-screen only — no DIO/pump wired up, see
     README "Known gaps")
  d. ITI — blank, config.t_iti
  e. repeat until config.n_trials

Output CSV columns are named to match the MATLAB Results table exactly,
so either stack's output can be loaded with the same downstream analysis
code. Eye tracking is dummy/mouse-only in this template — no pylink
integration yet, same caveat the MATLAB side's dummymode=1 covers.

Not runnable in this repo's nix devShell (no `psychopy` package there —
see README for setup with pip/the standalone PsychoPy app). Syntax-checked
with `python3 -m py_compile`, not executed against a real PsychoPy install.
"""

from __future__ import annotations

import csv
import math
import random
from datetime import datetime
from pathlib import Path

from psychopy import core, event, gui, visual

from config import Config

REPO_ROOT = Path(__file__).resolve().parent.parent


def load_pool(cfg: Config) -> list[dict]:
    pool_path = REPO_ROOT / cfg.pool_file
    with open(pool_path, newline="") as f:
        rows = list(csv.DictReader(f))
    for r in rows:
        r["duration_s"] = float(r["duration_s"])
    if len(rows) < 2:
        raise ValueError(f"Pool file {pool_path} has fewer than 2 videos.")
    return rows


def compute_ppd(win: visual.Window, cfg: Config) -> float:
    """Pixels per degree — same formula as CONFI_exp00_pilot.m's ppd calc."""
    ppcm = win.size[0] / cfg.screen_width_cm
    return 2 * cfg.obs_dist_cm * ppcm * math.tan(math.pi / 360)


def check_fixation(mouse: event.Mouse, fix_win_px: float) -> bool:
    """Dummy mode: mouse position stands in for gaze, same as MATLAB's
    dummymode. Window units='pix', origin at screen center, so this is
    just a centered box check — no offset math needed since fp_x/fp_y are
    both 0 in this template."""
    x, y = mouse.getPos()
    return abs(x) <= fix_win_px / 2 and abs(y) <= fix_win_px / 2


def wait_for_fixation(mouse: event.Mouse, fix_win_px: float, timeout: float) -> bool:
    clock = core.Clock()
    while clock.getTime() < timeout:
        if check_fixation(mouse, fix_win_px):
            return True
        core.wait(0.005)
    return False


def hold_fixation(mouse: event.Mouse, fix_win_px: float, hold_dur: float) -> bool:
    clock = core.Clock()
    while clock.getTime() < hold_dur:
        if not check_fixation(mouse, fix_win_px):
            return False
        core.wait(0.005)
    return True


def play_segment(win: visual.Window, movie: visual.MovieStim, seg_start: float, seg_dur: float) -> bool:
    """Seek, play for seg_dur, draw every frame. Returns True if ESC was
    pressed mid-segment."""
    movie.seek(seg_start)
    movie.play()
    clock = core.Clock()
    aborted = False
    while clock.getTime() < seg_dur:
        movie.draw()
        win.flip()
        if event.getKeys(["escape"]):
            aborted = True
            break
    movie.pause()
    return aborted


def draw_fixation(win: visual.Window, cfg: Config, ppd: float) -> visual.Circle:
    return visual.Circle(
        win,
        radius=cfg.fix_radius_deg * ppd,
        fillColor=cfg.fix_color,
        lineColor=cfg.fix_color,
        units="pix",
    )


def run_trial(
    win: visual.Window,
    trial_num: int,
    movies: dict[str, visual.MovieStim],
    pool_by_name: dict[str, dict],
    times_shown: dict[str, int],
    cfg: Config,
    mouse: event.Mouse,
    fix_dot: visual.Circle,
    reward_text: visual.TextStim,
    ppd: float,
) -> dict:
    fix_win_px = cfg.fix_window_deg * ppd
    row = {
        "TrialNum": trial_num,
        "VideoA": "", "CategoryA": "", "VideoB": "", "CategoryB": "",
        "SameCategory": "", "SegDur_s": cfg.seg_dur,
        "TimesShownBeforeA": "", "TimesShownBeforeB": "",
        "FixAcquired_ms": "", "InterleaveOff_ms": "", "RewardOn_ms": "",
        "AbortPhase": "None", "TrialSuccess": 0, "RewardSize": 0,
    }
    trial_clock = core.Clock()

    # a. fixation
    fix_dot.draw()
    win.flip()
    if not wait_for_fixation(mouse, fix_win_px, cfg.t_wait_fixation):
        print("\tFailed to acquire fixation.")
        row["AbortPhase"] = "Wait_for_fixation"
        core.wait(cfg.t_iti)
        return row
    if not hold_fixation(mouse, fix_win_px, cfg.t_hold_fixation):
        print("\tBroke fixation.")
        row["AbortPhase"] = "Hold_fix"
        core.wait(cfg.t_iti)
        return row
    row["FixAcquired_ms"] = trial_clock.getTime() * 1000

    # b. select + interleave
    name_a, name_b = random.sample(list(pool_by_name.keys()), 2)
    cat_a, cat_b = pool_by_name[name_a]["category"], pool_by_name[name_b]["category"]
    same_category = cat_a == cat_b
    print(f"\tA: {name_a:<20s} ({cat_a})   B: {name_b:<20s} ({cat_b})   "
          f"same-category={same_category}")

    aborted = False
    for si in range(cfg.segs_per_clip):
        seg_start = si * cfg.seg_dur
        if play_segment(win, movies[name_a], seg_start, cfg.seg_dur):
            aborted = True
            break
        if play_segment(win, movies[name_b], seg_start, cfg.seg_dur):
            aborted = True
            break

    win.color = (0, 0, 0)
    win.flip()
    row["InterleaveOff_ms"] = trial_clock.getTime() * 1000

    if aborted:
        row["AbortPhase"] = "Select_and_play"
        row["VideoA"], row["CategoryA"] = name_a, cat_a
        row["VideoB"], row["CategoryB"] = name_b, cat_b
        row["SameCategory"] = int(same_category)
        row["TimesShownBeforeA"] = times_shown[name_a]
        row["TimesShownBeforeB"] = times_shown[name_b]
        core.wait(cfg.t_iti)
        return row

    # c. unconditional reward (on-screen only — see README "Known gaps")
    reward_text.draw()
    win.flip()
    row["RewardOn_ms"] = trial_clock.getTime() * 1000
    core.wait(cfg.t_reward)

    row["VideoA"], row["CategoryA"] = name_a, cat_a
    row["VideoB"], row["CategoryB"] = name_b, cat_b
    row["SameCategory"] = int(same_category)
    row["TimesShownBeforeA"] = times_shown[name_a]
    row["TimesShownBeforeB"] = times_shown[name_b]
    row["TrialSuccess"] = 1
    row["RewardSize"] = cfg.reward_ms
    times_shown[name_a] += 1
    times_shown[name_b] += 1

    # d. ITI
    win.color = (0, 0, 0)
    win.flip()
    core.wait(cfg.t_iti)
    return row


def main():
    cfg = Config()

    dlg = gui.Dlg(title="exp_00 pilot (PsychoPy)")
    dlg.addField("Subject ID (<=8 chars):", "demo")
    ok = dlg.show()
    if not ok:
        print("Session cancelled by user")
        return
    sub_id = ok[0]
    if len(sub_id) > 8:
        raise ValueError("Subject ID must be 8 characters or fewer.")

    pool_rows = load_pool(cfg)
    pool_by_name = {r["filename"]: r for r in pool_rows}
    times_shown = {name: 0 for name in pool_by_name}
    print(f"\n--- exp_00 pilot pool ({len(pool_rows)} videos) ---")
    for r in pool_rows:
        print(f"  {r['filename']:<20s} {r['category']:<14s} {r['duration_s']:5.1f}s")
    print(f"segDur={cfg.seg_dur}s, perClipSeconds={cfg.per_clip_seconds}s "
          f"({cfg.segs_per_clip} segments/clip), nTrials={cfg.n_trials}\n")

    win = visual.Window(
        size=cfg.window_size, fullscr=cfg.fullscreen, screen=cfg.screen_number,
        color=(0, 0, 0), units="pix",
    )
    mouse = event.Mouse(win=win)
    ppd = compute_ppd(win, cfg)
    fix_dot = draw_fixation(win, cfg, ppd)
    reward_text = visual.TextStim(win, text="REWARD!", color=(-1, 1, -1), height=40)

    video_dir = Path(cfg.video_dir) / "video_all"
    movies = {}
    for name in pool_by_name:
        fp = video_dir / name
        if not fp.exists():
            raise FileNotFoundError(f"Pool video not found: {fp}")
        movies[name] = visual.MovieStim(win, str(fp), noAudio=True)

    out_dir = (
        Path(__file__).resolve().parent
        / "Output_exp00_pilot"
        / f"{sub_id}_{datetime.now():%Y-%m-%d_%H%M}"
    )
    out_dir.mkdir(parents=True, exist_ok=True)
    out_csv = out_dir / f"{sub_id}_{datetime.now():%Y-%m-%d_%H%M}.csv"

    fieldnames = [
        "TrialNum", "VideoA", "CategoryA", "VideoB", "CategoryB", "SameCategory",
        "SegDur_s", "TimesShownBeforeA", "TimesShownBeforeB",
        "FixAcquired_ms", "InterleaveOff_ms", "RewardOn_ms", "AbortPhase",
        "TrialSuccess", "RewardSize",
    ]

    total_trials = 0
    total_success = 0
    try:
        with open(out_csv, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()

            for trial_num in range(1, cfg.n_trials + 1):
                if event.getKeys(["escape"]):
                    print("ESC pressed, quitting.")
                    break
                total_trials += 1
                print(f"\n=== Trial #{total_trials} of {cfg.n_trials} "
                      f"(success so far={total_success}) ===")
                row = run_trial(win, total_trials, movies, pool_by_name,
                                 times_shown, cfg, mouse, fix_dot, reward_text, ppd)
                total_success += row["TrialSuccess"]
                writer.writerow(row)
                f.flush()

        print(f"Completed {total_trials} of {cfg.n_trials} planned trials.")
    finally:
        for m in movies.values():
            m.stop()
        win.close()
        core.quit()


if __name__ == "__main__":
    main()
