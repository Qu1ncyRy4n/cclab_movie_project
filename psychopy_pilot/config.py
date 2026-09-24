"""Config for exp_00 (PsychoPy version). Mirrors CONFI_exp00_pilot.m field
for field — same experiment, same knobs, different stack. Change values
here rather than in run_pilot.py.
"""

from dataclasses import dataclass, field
import os


@dataclass
class Config:
    # --- eye tracking ---
    # True = mouse-as-gaze (dummy mode, matches MATLAB's dummymode=1).
    # False = real EyeLink — NOT wired up yet in this template. See README.
    dummy_mode: bool = True

    # --- video location ---
    # Directory containing video_all/. Override with the CCLAB_VIDEO_DIR
    # env var instead of editing this for a one-off run on a new machine.
    video_dir: str = field(
        default_factory=lambda: os.environ.get(
            "CCLAB_VIDEO_DIR", os.path.expanduser("~/cclab_data/video_ebm_dataset")
        )
    )
    # video_ebm_dataset/pilot_pool.csv, relative to the repo root (this
    # file's grandparent directory).
    pool_file: str = "video_ebm_dataset/pilot_pool.csv"

    # --- exp_00 design (same as CONFI_exp00_pilot.m) ---
    seg_dur: float = 2.0            # interleave chunk length (s) — try 2 or 3
    per_clip_seconds: float = 6.0   # total per-clip screen time (s), from t=0
    # Halved (from 40) when the pool went from 2 to 4 videos/category
    # (2026-09-24), to keep per-video repetition roughly constant.
    n_trials: int = 20

    # --- timing (s) ---
    # No fixation-acquisition timeout by design — see
    # acquire_and_hold_fixation() in run_pilot.py. The dot waits
    # indefinitely; only the experimenter (ESC) ends a trial without one.
    t_hold_fixation: float = 0.85   # required hold before interleave starts
    t_iti: float = 2.0              # blank ITI — try 2 or 3
    t_reward: float = 1.0           # reward image on screen

    # --- fixation / window (deg) ---
    fix_window_deg: float = 3.0     # acceptance window half-width
    fix_radius_deg: float = 0.5     # fixation dot radius
    fix_color: tuple = (-1, -1, -1)  # PsychoPy RGB is -1..1; (-1,-1,-1) = black

    # --- reward ---
    # No DIO/pump integration in this template (see README) — this is
    # purely for the log and the on-screen "REWARD!" duration.
    reward_ms: int = 600

    # --- screen / geometry ---
    screen_number: int = 0
    fullscreen: bool = False
    window_size: tuple = (1080, 720)
    obs_dist_cm: float = 80.0
    screen_width_cm: float = 60.0

    @property
    def segs_per_clip(self) -> int:
        if self.per_clip_seconds % self.seg_dur != 0:
            raise ValueError(
                f"per_clip_seconds ({self.per_clip_seconds}) must be a whole "
                f"multiple of seg_dur ({self.seg_dur})."
            )
        return int(self.per_clip_seconds / self.seg_dur)
