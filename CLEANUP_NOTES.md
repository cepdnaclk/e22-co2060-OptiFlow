# Files that are safe (and recommended) to remove before the demo commit

## Auto-generated / should never be in git at all
- optiflow_back/__pycache__/           (all .pyc files)
- optiflow_back/tests/__pycache__/
- .idea/                                (JetBrains IDE workspace state)
- .vscode/                              (only settings.json + launch.json — keep if the team relies on shared launch configs, else drop)
- optiflow_front/android/build/reports/problems/problems-report.html   (Gradle build artifact, not source)

## Add a .gitignore instead of relying on manual deletion
__pycache__/
*.pyc
.idea/
build/
.env.local

## Judgement calls (ask your team before deleting)
- optiflow_front/fix_imports.dart / fix_imports.py / fix_strings.py
  These read like one-off migration scripts (e.g. bulk-renaming imports
  after a refactor). If the refactor is done and these were run once,
  they're clutter for a demo repo. If you still need to re-run them on
  CI or for new team members after a rebase, keep them.
- optiflow_back/.env.local
  Should NOT be committed at all if it contains real Supabase keys —
  check `git log -- optiflow_back/.env.local` for history and rotate
  the key if it was ever pushed.
- optiflow_gantt_fix.patch (repo root)
  This is already merged into commit 140755a per `git log`. Safe to
  delete now that it's historical — keep only if you want it as a
  paper trail of "what we fixed and why" for your report.
- seed_pitch_data.py vs seed_pitch_demo_job.py vs seed_demo_final.py (new)
  These are NOT redundant — see SEED_ORDER below. Don't delete any of
  the first two; seed_demo_final.py is additive on top of them.

## SEED ORDER for the demo
1. seed_pitch_data.py       — wipes and rebuilds the whole base dataset
                               (5 machines, 4 humans, fixed UUIDs)
2. create_minders.py        — registers Supabase Auth logins for
                               Elena/Marcus/Sarah (only needs to run once
                               ever, not once per seed — it's keyed on
                               Supabase Auth, not the DB tables above)
3. seed_pitch_demo_job.py   — adds one small Print->Fold->Cut job
4. seed_demo_final.py       — adds one richer Print->Fold->Sew->Cut job
                               with a 2-candidate-per-op skills matrix
   (optional) --clear-today flag on seed_demo_final.py resets any
   already-SCHEDULED tasks for today back to PENDING right before you
   go on stage, so Optimize has visible, dramatic work to do.
