"""Builds the Gang Retaliation (map filter / stronghold / intel work) release package from Working/.

  python -I build_release.py [--skip-checks]

1. Pre-flight (unless --skip-checks): offline redscript compile check of THIS tree's scripts (Working/GangRetaliation)
   with Codeware + TweakXL, using the game's own scc.exe in a scratch folder. Aborts on failure.
2. Verifies VERSION below matches CHANGELOG.md and README.md.
3. Writes the in-game tree (archive/, bin/, r6/) to Distribution/GangRetaliation/<version>/ and builds
   "Gang Retaliation V<version>.zip" from only that tree. README, CHANGELOG, docs/ and build/ are NOT shipped.
   RELEASE_NOTES.md in the version folder is regenerated from CHANGELOG.md.
Never touches the game folder. Warns (does not fail) if the installed scripts differ from this tree.
"""
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
MOD = HERE.parent                                   # Working/GangRetaliation
ROOT = MOD.parent.parent                            # CYBERPUNK MODS
NAME = "GangRetaliation"
VERSION = "1.5.7"
ZIP_NAME = f"Gang Retaliation V{VERSION}.zip"

GAME = Path(r"H:\SteamLibrary\steamapps\common\Cyberpunk 2077")
SCC = GAME / "engine" / "tools" / "scc.exe"
SHIPPED_TOP = ["archive", "bin", "r6"]              # top-level folders that go in the zip
SCRIPTS = Path("r6/scripts") / NAME
INIT_LUA = Path("bin/x64/plugins/cyber_engine_tweaks/mods") / NAME / "init.lua"


def fail(msg):
    sys.exit("BUILD FAILED: " + msg)


def ship_files():
    files = []
    for top in SHIPPED_TOP:
        for p in sorted((MOD / top).rglob("*")):
            if p.is_file():
                files.append(p.relative_to(MOD))
    return files


def compile_check():
    print("== pre-flight: offline compile check")
    if not SCC.is_file():
        fail(f"scc.exe not found at {SCC}")
    scratch = Path(tempfile.gettempdir()) / "gr_build_scc"      # system temp: no OneDrive locks
    if scratch.exists():
        def unlock(func, path, _exc):
            Path(path).chmod(0o700)
            func(path)
        shutil.rmtree(scratch, onerror=unlock)
    scripts = scratch / "r6" / "scripts"
    (scratch / "r6" / "cache").mkdir(parents=True)
    (scratch / "out").mkdir()
    shutil.copy(GAME / "r6" / "cache" / "final.redscripts", scratch / "r6" / "cache" / "final.redscripts")
    shutil.copytree(MOD / SCRIPTS, scripts / NAME)
    shutil.copytree(GAME / "red4ext" / "plugins" / "Codeware" / "Scripts", scripts / "_deps" / "Codeware")
    shutil.copytree(GAME / "red4ext" / "plugins" / "TweakXL" / "Scripts", scripts / "_deps" / "TweakXL")
    out = scratch / "out" / "final.redscripts"
    r = subprocess.run([str(SCC), "-compile", str(scripts), str(out)], cwd=scratch,
                       capture_output=True, text=True, errors="replace")
    text = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0 or not out.exists():
        print(text[-3000:])
        fail(f"redscript compile failed (exit code {r.returncode})")
    print("   compiles cleanly")


def check_version():
    checks = [
        (Path("CHANGELOG.md"), rf"^## \[?{re.escape(VERSION)}\]?\b"),
        (Path("README.md"), rf"Current version: {re.escape(VERSION)}\b"),
        # Mod Settings version display (en + es, same untranslated "Gang Retaliation vX.X.X" text in both).
        (Path("r6/scripts/GangRetaliation/Localization.reds"), rf'"Gang Retaliation v{re.escape(VERSION)}"'),
        # CET overlay window title.
        (INIT_LUA, rf'VERSION = "{re.escape(VERSION)}"'),
    ]
    for rel, pattern in checks:
        text = (MOD / rel).read_text(encoding="utf-8")
        if not re.search(pattern, text, re.M):
            fail(f"version check failed for {rel} (expected {pattern})")
    print(f"== version {VERSION} consistent")


def transform_init_lua(text: str) -> str:
    # Never ship with dev mode on - it turns on the FPS/perf overlay, benchmark tooling, the fly hotkey,
    # etc., none of which belongs in a build players run. Mirrors the toggle NovaAntonsito's own release
    # build makes (found 2026-11-19 by diffing the packaged 1.4.9 Nexus zip against the exact git commit
    # it was built from - see NOTES.md section 2).
    replaced, count = re.subn(r"dev = true,\s*--\s*GR_DEV_FLAG", "dev = false,", text)
    if count != 1:
        fail(f"expected exactly one GR_DEV_FLAG line in init.lua, found {count}")
    return replaced


def shipped_bytes(rel: Path) -> bytes:
    data = (MOD / rel).read_bytes()
    if rel == INIT_LUA:
        data = transform_init_lua(data.decode("utf-8")).encode("utf-8")
    return data


def warn_if_installed_differs():
    for p in sorted((MOD / SCRIPTS).glob("*.reds")) + [MOD / "r6/tweaks/GangRetaliation/intel.yaml"]:
        installed = GAME / p.relative_to(MOD)
        if not installed.is_file() or installed.read_bytes() != p.read_bytes():
            print(f"   WARNING: installed copy differs from Working: {p.relative_to(MOD)}")


def release_notes():
    text = (MOD / "CHANGELOG.md").read_text(encoding="utf-8")
    m = re.search(rf"^## \[?{re.escape(VERSION)}\]?\b.*?(?=^## |\Z)", text, re.M | re.S)
    return m.group(0).rstrip() + "\n"


def main():
    if "--skip-checks" not in sys.argv:
        compile_check()
    check_version()
    warn_if_installed_differs()
    files = ship_files()
    if not files:
        fail("nothing to ship")

    out = ROOT / "Distribution" / NAME / VERSION
    stage = Path(tempfile.mkdtemp(prefix="grmod_release_"))
    zip_path = stage / ZIP_NAME
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in files:
            z.writestr(rel.as_posix(), shipped_bytes(rel))

    out.mkdir(parents=True, exist_ok=True)
    for rel in files:                                   # copy file by file; never delete anything there
        target = out / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(shipped_bytes(rel))
    shutil.copy2(zip_path, out / ZIP_NAME)
    (out / "RELEASE_NOTES.md").write_text(release_notes(), encoding="utf-8")

    with zipfile.ZipFile(out / ZIP_NAME) as z:
        names = z.namelist()
    for bad in ("README.md", "CHANGELOG.md", "RELEASE_NOTES.md", "build_release.py"):
        if any(n.endswith(bad) for n in names):
            fail(f"{bad} must not be inside the zip")
    if sorted(names) != sorted(f.as_posix() for f in files):
        fail("zip contents do not match the in-game tree")
    print(f"\nOK: {out / ZIP_NAME}  ({(out / ZIP_NAME).stat().st_size} bytes, {len(names)} files)")


if __name__ == "__main__":
    main()
