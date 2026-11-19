# Handover: nemesis detail panel / fallen-row scrollbars - RESOLVED

Written 2026-11-19, updated same day once the user confirmed in game: **"everything is working as
expected."** Kept below for the full history, in case this ever regresses - the final fix (section 5) is
not fully isolated, see its caveat.

## 0. What this session actually built (separate from the bug below)

Starting point: the nemesis detail panel (`Menu.reds`'s `CreateDetail`/`FillDetail`, opened from the GANGS
view by clicking a nemesis card) could overflow past the card's bottom edge for a nemesis with lots of
traits - it was a single `inkVerticalPanel`, no scrolling. The FALLEN row (`AddFallen`) only ever showed 5
cards + a plain "+N" text, cards were too short for the cause-of-death line, and nothing was clickable.

Implemented, all confirmed working except the scrollbar visuals themselves (section 1):
- Detail panel split into a fixed header (rank/gang line, name, title) + a scrollable body for everything
  else (contact tag through Origin), with a thin divider between them (confirmed centered, confirmed
  correct gap after a couple of rounds with the user).
- FALLEN cards made taller (190px), cause-of-death moved to its own line below rank, both name and cause
  now wrap instead of overflowing.
- FALLEN "+N" is now a bordered button (`AddFallenActionCard`) that expands the full fallen list in a
  horizontally-scrollable row with a "<" card at the end to collapse back (same button styling).
- Every fallen card (collapsed or expanded) is clickable and opens that nemesis in the same side detail
  panel a living nemesis does, via a new parallel `m_fallenCards` array (doesn't collide with `m_cards`,
  the living-roster one).
- FALLEN header's divider length now computed from the actual row width (card count + whether "+N" is
  shown) instead of a flat guess, so it reaches the end of the "+N" button - confirmed correct.
- Fixed a real cross-contamination bug: both scroll areas had `useGlobalInput = true`, which made the
  mouse wheel scroll *both* the detail panel and the fallen row at once regardless of what was actually
  hovered. Set to `false` on both (and on `GangRetaliationHistory/History.reds`'s two scroll areas too,
  same bug there) - **confirmed fixed**, individual-section scrolling now works correctly.
- Grip color (red at rest, cyan while held) didn't reliably reset if the mouse was dragged off the grip
  before release. Fixed by moving the reset into the existing global `OnPostOnRelease` handler
  (`OnGRGlobalInput`), which fires regardless of where the pointer lets go - matches
  `GangRetaliationHistory/History.reds`'s own `OnGRChronInput` pattern. **Not yet re-confirmed** after the
  later rounds of scrollbar changes below; worth a quick re-check once the main bug is fixed.
- Version bumped to 1.5.0 for all of this (`build/build_release.py`'s `VERSION`, `GR-SetVersion` in
  `Localization.reds` EN+ES, `README.md`'s "Current version", a new `## [1.5.0]` `CHANGELOG.md` entry).
- Separately: `build_release.py` now strips `dev = true` down to `dev = false` in the shipped `init.lua`
  copy (matching what NovaAntonsito's own release zip does, confirmed by diffing their packaged 1.4.9
  against the exact git commit it was built from) - `Working/`'s own copy stays `dev = true` for testing.
  Also fixed `check_version`/`release_notes`'s regex, which never actually matched this repo's
  `## [X.Y.Z] - date` changelog format (`^## {VERSION}\b` with no bracket handling) - this had silently
  been broken since before this session, unrelated to today's feature work.

## 1. The unresolved bug

**The detail panel's vertical scrollbar (and, after a later change, possibly the fallen row's horizontal
one too) does not display or behave correctly**, despite the underlying content scrolling being confirmed
correct the whole time (wheel input moves the right content in the right direction; only the *visual
grip/background* is wrong). Symptoms reported across rounds, not all simultaneously:
- Grip moves in the opposite direction from the actual scroll (reported for both wheel and drag at
  different points).
- Grip briefly too small (when `autoSizeHandle = true` was tried).
- The dim-red background track behind the grip never renders at all - confirmed with an opaque bright-cyan
  diagnostic fill, still nothing. The grip itself always renders fine.
- When reverted to match `GangRetaliationHistory/History.reds`'s working vertical bar *exactly*
  (`VerticalScrollBarRef` automatic sync + `autoSizeHandle = true`), behavior got **worse**, not better:
  tiny grip again, both wheel and drag backwards, background still missing. This is the most important
  single data point - it means there is a real, still-unidentified difference between this screen's
  context and History's, despite the bar/host/scroll construction appearing line-for-line identical on
  several careful re-reads. **The user explicitly said as much: "theres something youre missing between
  history and here."** Take that literally - don't re-try "match History exactly" again without first
  finding what the actual remaining difference is (see section 3).

## 2. What's been tried, in order, with outcomes (DO NOT repeat these blindly)

1. `VerticalScrollBarRef` auto-sync, `autoSizeHandle = false`, bar parented as a *sibling* of the scroll
   host (positioned on `detail` directly) → grip existed but drifted/moved wrong.
2. Same, `autoSizeHandle = true` → grip correctly got smaller (so autoSizeHandle does work mechanically),
   still moved wrong - direction wasn't the parenting's fault alone.
3. **Fixed the real structural bug found by this point**: bar must be a *child of the same canvas the
   scroll area lives in* (`host`), not a sibling positioned elsewhere - matches History's structure. Also
   switched to a fully manual two-way sync (`OnGRDetailScrolled`/`OnGRDetailDragged`, mirroring the
   fallen-row's horizontal bar's own manual sync, `OnGRFallenScrolled`/`OnGRFallenDragged`) instead of
   `VerticalScrollBarRef`, with `autoSizeHandle = false` and a fixed-size grip. Grip no longer tiny. Still
   backwards.
4. Inverted the value fed to the slider in both directions (`1.0 - position` / `1.0 - progress`) on the
   theory that a vertical `inkSliderController`'s value runs bottom-to-top (volume-fader convention)
   opposite of a scrollbar's top-to-bottom. Wheel became directionally correct per the user. Drag was
   still backwards.
5. Found a real reentrancy bug: `OnGRDetailDragged`'s `SetScrollPosition` call fires `OnScrollChanged`,
   which re-enters `OnGRDetailScrolled` and reasserts a competing value on the slider *during* the user's
   own drag. Added `m_detailSyncing` guard around the call in `OnGRDetailDragged` too (it was only guarded
   in `OnGRDetailScrolled` before). Also around this point: added explicit anchor/margin to the track
   rect, still no visible background.
6. User reported "scrolled all the way down with the wheel" while the grip sat near the TOP - direct
   evidence the end-state mapping was still wrong, contradicting the earlier "wheel is correct" read
   (which may have only been checked on a partial/small scroll).
7. Tried `AddFill` instead of a raw `NewRect` for the track (the one background mechanism confirmed
   working everywhere else in this file, e.g. every card fill) - **in the same round** also reverted to
   `VerticalScrollBarRef` auto-sync + `autoSizeHandle = true` to match History exactly. This conflated two
   independent changes. Result: tiny grip again, both directions backwards, **still no background even
   with AddFill**. This ruled out "NewRect vs AddFill" as the background's cause, but the test was
   contaminated by also changing the sync mechanism at the same time - AddFill was never cleanly tested
   against the version that had wheel-scroll confirmed correct (step 4-5's state).
8. Reverted back to the manual-sync version from step 5 (restoring `1.0 - position` / `1.0 - progress` +
   the reentrancy guard), keeping `AddFill`. **New hypothesis**: the `inkSliderController`, once attached
   to the bar canvas via `AttachController`, may only render/manage children it knows about through
   `handleRef` (the grip) - a plain sibling child added for the background may be getting ignored/hidden
   by the slider taking over rendering for that canvas, regardless of which API builds it. Moved the
   track out of the slider-controlled canvas entirely: new `NewTrack(parent, x, y, w, h)` helper builds an
   independent sibling canvas (not a child of `bar`) at the same position, using `AddFill`. Applied to both
   the vertical bar (`NewBar`, called from `CreateDetail`) and the horizontal one (`NewHBar`, called from
   `AddFallen`'s expanded view), even though the horizontal one's background was reportedly fine before -
   for consistency and to test whether the hypothesis is universal. **This is the current deployed state,
   not yet tested by the user.**

## 3. If the current deployed state (step 8) still doesn't work

Ideas not yet tried, roughly in order of how promising they seem:

- **Get real numbers.** A live on-screen diagnostic text showing the raw `this.m_detailScroller.position`
  value was built once (step 6-7 era) and then removed when pivoting to the History-exact revert, without
  ever actually being used to read real data - re-add it (search git history / this file's earlier state,
  or just rebuild it: an `inkText` on `detail`, updated inside `OnGRDetailScrolled`) and get the user to
  report the actual numbers at top/middle/bottom of a scroll, rather than continuing to infer the sign
  algebraically from directional reports alone, which has produced contradictory conclusions multiple
  times already (see step 4 vs step 6).
- **Check for something upstream of this specific widget tree**, not just the bar/host/scroll construction
  itself: is there a transform, mask, or scale applied to `detail`, `m_tree`, or `root` that doesn't exist
  on History's equivalent `panel`/`m_root`? Already ruled out: `rootResolution` (both screens are
  `UltraHD_3840_2160`, confirmed by extracting `gangretaliation/gui/nemesis.inkwidget` with WolvenKit.CLI
  and checking the JSON).
- **Try `inkSliderController` with no `handleRef` sized/positioned override at all** - i.e. let
  `autoSizeHandle` fully own the grip's geometry rather than also calling `grip.SetSize(...)` ourselves
  beforehand up front; maybe the explicit SetSize call is fighting the controller's own sizing logic in a
  way that also affects whether siblings render (a stretch, but untested).
- Consider whether `GRNemesisMenuController` (this file) has some *other* method elsewhere in this
  3200+-line file that overrides scroll/pointer input in a way that conflicts (e.g. another
  `OnScrollChanged`-style registration, or a wrap/override of a base `inkScrollController`-related method)
  - not found in a search for `useGlobalInput`/`OnScroll`/`inkSliderController` so far, but a fresh,
  broader grep for anything touching `inkScrollArea`/`ScrollController`/pointer wheel handling elsewhere in
  the class wouldn't hurt.
- Worth asking Nova directly whether she's seen this exact issue before, given she wrote the surrounding
  menu code this screen extends.

## 5. The actual fix (2026-11-19, later the same day)

Two changes landed together, then confirmed working in one in-game test - so it's not proven which one
actually mattered, or whether both did. If this ever regresses, test them independently before assuming:

1. **Removed the leftover manual sync.** Step 7 above tried matching History's `VerticalScrollBarRef` +
   `autoSizeHandle = true` exactly, and called it "worse" - but that attempt still had `OnGRDetailScrolled`/
   `OnGRDetailDragged` registered via `bar.RegisterToCallback(n"OnSliderValueChanged", ...)` and
   `scroll.RegisterToCallback(n"OnScrollChanged", ...)` at the same time as `VerticalScrollBarRef`'s own
   automatic sync - two mechanisms driving the same slider. Deleted both callbacks, their registrations,
   and the now-unused `m_detailSyncing` field entirely. `NewBar` is back to a plain `AddFill`-based track
   as a *child* of `bar` (removed the sibling `NewTrack` helper added in step 8, applied to both the
   vertical bar and the fallen row's horizontal one, which had never actually had a background problem).
2. **Replaced a derived read with a literal.** `CreateDetail` computed the host/bar height as
   `host.GetSize().Y`, read back immediately after `host.SetSize(...)` - the one non-literal value left in
   a function otherwise built to match History's all-literal `NewBar(host, 2136.0, 0.0, 10.0, 1240.0,
   false)` call. Not confirmed as an actual bug (`inkCanvas.GetSize()` is a plain stored-property read, not
   layout-dependent, so it should have returned the just-set value correctly) - the user flagged it as the
   one visible difference from History's style, and replacing it with a named `hostHeight: Float` local
   used for both `host.SetSize` and the `NewBar` call removed the question entirely rather than leaving it
   as the last unverified assumption.

## 4. Files touched

`r6/scripts/GangRetaliation/Menu.reds` (all of the above), `r6/scripts/GangRetaliation/Localization.reds`
(version string + a short-lived `GR-MenuShowLess` key that was added then removed again once the collapse
button became an icon instead of text), `r6/scripts/GangRetaliationHistory/History.reds` (the
`useGlobalInput` fix only - its own vertical bar's direction/background were NOT touched and are reportedly
fine), `build/build_release.py`, `README.md`, `CHANGELOG.md`.

See `NOTES.md` section 5 for the shorter pointer to this file.
