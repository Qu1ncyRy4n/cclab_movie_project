"""QC checks for one exp00 run (PICKUP 2026-10-26 plan, checks 1, 5, 8, 12).

Usage: python3 qc_exp00.py <run_dir>
Needs <run_dir>/derived/trials_from_mat.csv (MATLAB export, see notebook) and
the .asc next to the .edf (edf2asc -y). Stdlib only, so it runs outside nix.
Writes <run_dir>/derived/qc_report.json; exits 1 if any hard check fails.
"""
import csv
import json
import re
import statistics as st
import sys
from bisect import bisect_left
from collections import Counter, defaultdict
from pathlib import Path

run = Path(sys.argv[1])
asc = next(run.glob('experiment/**/*.asc'))
log_path = next(run.glob('experiment/**/event_log.csv'))
plan_path = next(run.glob('experiment/**/session_plan.csv'))
trials = list(csv.DictReader(open(run / 'derived/trials_from_mat.csv')))
log = list(csv.DictReader(open(log_path)))
plan = list(csv.DictReader(open(plan_path)))

fails, report = [], {}


def check(ok, msg):
    if not ok:
        fails.append(msg)


def summ(xs):
    xs = sorted(xs)
    q = lambda p: xs[min(len(xs) - 1, int(p * len(xs)))]
    return {'n': len(xs), 'min': xs[0], 'p01': q(.01), 'median': st.median(xs),
            'p99': q(.99), 'max': xs[-1]}


# ---- parse ASC once ----
msgs, t_samp, lost = [], [], bytearray()
blinks = []
seg_re = re.compile(r'Seg(On|Off)_(\d+)_(\d+)_([AB])$')
for line in open(asc, errors='replace'):
    c = line[0]
    if c.isdigit():
        f = line.split('\t', 3)
        t_samp.append(int(f[0]))
        lost.append(f[1].strip() == '.')  # lost samples are '.', not numbers
    elif line.startswith('MSG'):
        _, t, label = line.rstrip('\n').split(None, 2)
        msgs.append((int(t), label))
    elif line.startswith('EBLINK'):
        f = line.split()
        blinks.append((int(f[2]), int(f[3])))

edf = defaultdict(list)  # trial -> [(t, kind, seg, movie)]
edf_counts = Counter()
for t, label in msgs:
    m = seg_re.match(label)
    if m:
        edf[int(m[2])].append((t, 'Seg' + m[1], int(m[3]), m[4]))
        edf_counts['Seg' + m[1]] += 1
    else:
        kind, _, n = label.rpartition('_')
        if kind in ('TrialStart', 'FixInFP', 'Reward') and n.isdigit():
            edf[int(n)].append((t, kind, None, None))
            edf_counts[kind] += 1

# ---- check 12: eye-track loss (the notebook's regex silently drops '.') ----
def lost_frac(t0, t1):
    i, j = bisect_left(t_samp, t0), bisect_left(t_samp, t1)
    return (sum(lost[i:j]), j - i)


per_trial_loss = {}
for tr, ev in edf.items():
    segs = {(s, mv, k): t for t, k, s, mv in ev if s}
    nl = nn = 0
    for (s, mv, k), t in segs.items():
        if k == 'SegOn' and (s, mv, 'SegOff') in segs:
            a, b = lost_frac(t, segs[(s, mv, 'SegOff')])
            nl, nn = nl + a, nn + b
    per_trial_loss[tr] = nl / nn if nn else None
movie_loss = [v for v in per_trial_loss.values() if v is not None]
report['12_track_loss'] = {
    'samples': len(t_samp),
    'lost_samples': sum(lost),
    'lost_frac_whole_file': round(sum(lost) / len(t_samp), 4),
    'lost_frac_during_movies_per_trial': {k: round(v, 3) for k, v in summ(movie_loss).items()},
    'trials_over_20pct_lost': sorted(t for t, v in per_trial_loss.items() if v and v > .2),
    'trials_over_50pct_lost': sorted(t for t, v in per_trial_loss.items() if v and v > .5),
    'blinks': len(blinks),
    'loss_first_vs_last_third': [
        round(st.mean(per_trial_loss[t] for t in sorted(per_trial_loss)[:60]), 3),
        round(st.mean(per_trial_loss[t] for t in sorted(per_trial_loss)[-60:]), 3)],
}

# ---- check 5 (+6 order): event counts and order agree across streams ----
log_counts = Counter(r['event'] for r in log)
n = len(trials)
success = sum(int(r['TrialSuccess']) for r in trials)
seg_per = 2 * int(round(6 / float(trials[0]['SegDur_s'])))  # A+B segments per trial
report['5_counts'] = {'results_rows': n, 'results_success': success, 'plan_rows': len(plan),
                      'edf': dict(edf_counts), 'event_log': dict(log_counts),
                      'FixInFP_per_trial': dict(Counter(Counter(
                          t for t, ev in edf.items() for e in ev if e[1] == 'FixInFP').values()))}
check(n == len(plan), f'5: {n} Results rows vs {len(plan)} plan rows')
for k_edf, k_log, want in [('TrialStart', 'TrialStart', n), ('SegOn', 'SegmentOn', n * seg_per),
                           ('SegOff', 'SegmentOff', n * seg_per), ('Reward', 'Reward', success)]:
    check(edf_counts[k_edf] == want, f'5: EDF {k_edf}={edf_counts[k_edf]}, want {want}')
    check(log_counts[k_log] == want, f'5: event_log {k_log}={log_counts[k_log]}, want {want}')
check(log_counts['PairSelected'] == n, '5: PairSelected count != trials')
end = [r for r in log if r['event'] == 'SessionEnd']
check(end and end[0]['detail'] == f'successes={success}', f'5: SessionEnd {end} vs {success}')
log_by_trial = defaultdict(list)
for r in log:
    if r['trial'] not in ('', 'NaN'):
        log_by_trial[int(float(r['trial']))].append(r)
want_order = [(k, s, mv) for s in range(1, seg_per // 2 + 1) for mv in 'AB' for k in ('SegOn', 'SegOff')]
for r in trials:
    tr, ok = int(r['TrialNum']), r['TrialSuccess'] == '1'
    ev = sorted(edf[tr])
    kinds = [e[1] for e in ev]
    segs = [(k, s, mv) for _, k, s, mv in ev if s]
    if ok:
        check(segs == want_order, f'6: trial {tr} EDF segment order {segs}')
        check(kinds[0] == 'TrialStart' and kinds[-1] == 'Reward', f'6: trial {tr} EDF starts/ends {kinds[0]}/{kinds[-1]}')
        check(max(i for i, k in enumerate(kinds) if k == 'FixInFP') < kinds.index('SegOn'),
              f'6: trial {tr} FixInFP after first SegOn')
        lsegs = [('SegOn' if x['event'] == 'SegmentOn' else 'SegOff', int(float(x['segment'])),
                  x['detail'].split(';')[0][-1]) for x in log_by_trial[tr] if x['event'].startswith('Segment')]
        check(lsegs == want_order, f'6: trial {tr} event_log segment order')
    check(kinds.count('Reward') == int(ok), f'5: trial {tr} reward/success mismatch')

# ---- check 8: segment timing from EDF clock (event_log is 1 s resolution) ----
dur, gap, inter, by_video, by_pos = [], [], [], defaultdict(list), defaultdict(list)
vid = {int(r['TrialNum']): (r['VideoA'], r['VideoB']) for r in trials}
for tr, ev in edf.items():
    s = sorted(e for e in ev if e[2])
    on = {(e[2], e[3]): e[0] for e in s if e[1] == 'SegOn'}
    off = {(e[2], e[3]): e[0] for e in s if e[1] == 'SegOff'}
    for key in on:
        if key in off:
            d = off[key] - on[key]
            dur.append(d)
            by_video[vid[tr][key[1] == 'B']].append(d)
            by_pos[f'seg{key[0]}{key[1]}'].append(d)
    for a, b in zip(s, s[1:]):
        if a[1] == 'SegOff' and b[1] == 'SegOn':
            gap.append(b[0] - a[0])
    if s:
        inter.append(s[-1][0] - s[0][0])
nominal = float(trials[0]['SegDur_s']) * 1000
frame = 1000 / 120  # lab_120 profile
report['8_timing_ms'] = {
    'segment_dur': summ(dur),
    'segments_off_by_more_than_1_frame': sum(abs(d - nominal) > frame for d in dur),
    'segments_off_by_more_than_100ms': sum(abs(d - nominal) > 100 for d in dur),
    'switch_gap_SegOff_to_next_SegOn': summ(gap),
    'interleave_total': summ(inter),
    'median_dur_by_position': {k: st.median(v) for k, v in sorted(by_pos.items())},
    'worst_videos_by_median_dur': sorted(((round(st.median(v), 1), k) for k, v in by_video.items()),
                                         reverse=True)[:8],
}
# The gap is seek latency (the previous movie's last frame stays frozen on
# screen). If it scales with distance from the preceding keyframe, the
# decoder is rolling forward to the exact target, i.e. seeks are accurate,
# not snapping to keyframes.
kf = {r['filename']: [float(x) for x in r['keyframes'].split(';')]
      for r in csv.DictReader(open(Path(__file__).parent.parent / 'video_ebm_dataset/cuts.csv'))}
plan_by = {int(p['TrialNum']): p for p in plan}
kd, lat = [], []
for tr, ev in edf.items():
    s = sorted(e for e in ev if e[2])
    for a, b in zip(s, s[1:]):
        if a[1] == 'SegOff' and b[1] == 'SegOn':
            p = plan_by[tr]
            target = float(p['Start' + b[3] + '_s']) + float(trials[0]['SegDur_s']) * (b[2] - 1)
            k = kf[p['Video' + b[3]]]
            kd.append(target - k[bisect_left(k, target + 1e-9) - 1])
            lat.append(b[0] - a[0])
fit = st.linear_regression(kd, lat)
report['8_timing_ms']['seek_latency_vs_keyframe_distance'] = {
    'corr': round(st.correlation(kd, lat), 3),
    'intercept_ms': round(fit.intercept), 'ms_per_s_from_keyframe': round(fit.slope)}
# ponytail: thresholds are first-guess; tighten once a clean run sets the baseline
check(st.median(dur) < nominal + 50, f'8: median segment {st.median(dur)} ms vs nominal {nominal}')

# ---- check 1: plan fidelity (videos/categories/condition/repetition counts) ----
pairs = {int(float(r['trial'])): dict(kv.split('=') for kv in r['detail'].split(';'))
         for r in log if r['event'] == 'PairSelected'}
seen, mism = Counter(), []
for p, r in zip(plan, trials):
    tr = int(r['TrialNum'])
    exp = (p['TrialNum'], p['VideoA'], p['VideoB'], p['CategoryA'], p['CategoryB'])
    got = (r['TrialNum'], r['VideoA'], r['VideoB'], r['CategoryA'], r['CategoryB'])
    if exp != got:
        mism.append(f'trial {tr}: plan {exp} vs results {got}')
    pl = pairs.get(tr, {})
    if (pl.get('A'), pl.get('B')) != (p['VideoA'], p['VideoB']):
        mism.append(f'trial {tr}: plan {p["VideoA"]},{p["VideoB"]} vs event_log {pl}')
    same = int(p['CategoryA'] == p['CategoryB'])
    if int(r['SameCategory']) != same or int(pl.get('sameCategory', -1)) != same:
        mism.append(f'trial {tr}: SameCategory mismatch')
    if p['Condition'] != ''.join(sorted(c[0].upper() for c in (p['CategoryA'], p['CategoryB']))):
        mism.append(f'trial {tr}: Condition {p["Condition"]} vs categories')
    if (int(r['TimesShownBeforeA']), int(r['TimesShownBeforeB'])) != (seen[p['VideoA']], seen[p['VideoB']]):
        mism.append(f'trial {tr}: TimesShownBefore {r["TimesShownBeforeA"]},{r["TimesShownBeforeB"]} '
                    f'vs recount {seen[p["VideoA"]]},{seen[p["VideoB"]]}')
    seen[p['VideoA']] += 1
    seen[p['VideoB']] += 1
report['1_plan_fidelity'] = {
    'mismatches': mism[:20], 'n_mismatches': len(mism),
    'conditions': dict(Counter(p['Condition'] for p in plan)),
    'videos': len(seen), 'showings_per_video': summ(list(seen.values())),
    'note': 'Start_s is only in the plan; actual seek position is not logged, so it is unverifiable from data (see test_seek).',
}
check(not mism, f'1: {len(mism)} plan mismatches')

report['fails'] = fails
(run / 'derived/qc_report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
sys.exit(1 if fails else 0)
