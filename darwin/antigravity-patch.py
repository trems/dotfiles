#!/usr/bin/env python3
"""Self-contained Antigravity patcher (agy CLI + language_server).

Runs from the nix-darwin activation hook on every `darwin-rebuild switch`
(binaries get replaced by cask/app updates). Idempotent: already-patched
targets are skipped. Exit 0 = all patched (or nothing applicable); exit 1 =
something needed a patch but wasn't patched (locked / unsupported version /
error) — the hook turns that into a console warning.

Methodology, gate history and pitfalls for adapting to new agy versions:
see antigravity-patch.md next to this file.
"""

import glob
import mmap
import os
import re
import contextlib
import filecmp
import shutil
import subprocess
import sys

BAK_EXT = ".agybak"

APP_BIN_GLOB = "/opt/homebrew/Caskroom/antigravity/*/Antigravity.app/Contents/Resources/bin/language_server"
AGY_BIN = "/opt/homebrew/bin/agy"


# ------------------------------------------------------------------- gates --
class Gate:
    """Byte-signature patch: regex over machine code, 4+ byte fix, ad-hoc resign."""

    def __init__(self, sig, patched, fix, offset=0, desc=""):
        self.sig = re.compile(sig, re.S)
        self.patched = re.compile(patched, re.S)
        self.fix = fix
        self.offset = offset
        self.desc = desc

    def resolve(self, data):
        """('patched'|'unpatched', [write-offsets], self). LookupError if absent."""
        patched = [m.start() + self.offset for m in self.patched.finditer(data)]
        if patched:
            return ("patched", patched, self)
        unpatched = [m.start() + self.offset for m in self.sig.finditer(data)]
        if not unpatched:
            raise LookupError("gate signature not found (unsupported version?)")
        return ("unpatched", unpatched, self)


class MultiGate:
    """One logical gate, several arch/version variants; first match wins."""

    def __init__(self, *gates, desc=""):
        self.gates = gates
        self.desc = desc

    def resolve(self, data):
        err = None
        for g in self.gates:
            try:
                return g.resolve(data)
            except LookupError as e:
                err = e
        raise err or LookupError("no gate signature matched")


# agy CLI eligibility gate, x64 (1.0.x):
#   test rax,rax; je eligible; cmp byte[rax+8],0; jne eligible
CLI_GATE_X64 = Gate(
    rb"\x48\x85\xc0\x0f\x84....\x80\x78\x08\x00\x0f\x85....",
    rb"\x48\x85\xc0\x0f\x84....\x48\x85\xc0\x90\x0f\x85....",
    b"\x48\x85\xc0\x90",
    offset=9,
    desc="eligibility screen off (x64)",
)
# agy CLI eligibility gate, arm64 (1.0.x):
#   cbnz x1,err; cbz x0,eligible; ldrb w1,[x0,#8]; tbnz w1,#0,eligible
CLI_GATE_ARM64 = Gate(
    rb"...\xb5...\xb4\x01\x20\x40\x39...\x37",
    rb"...\xb5...\xb4\x21\x00\x80\x52...\x37",
    b"\x21\x00\x80\x52",
    offset=8,
    desc="eligibility screen off (arm64)",
)
# agy CLI eligibility gate, arm64 (1.5.6+): same semantics, moved into the
# fetchPlanTier verdict closure. Patch ONLY this verdict check — silencing
# validateEligibilityWithRetry or forcing the verdict delivery byte breaks
# the model catalog / crashes printmode (see antigravity-patch.md).
CLI_GATE_ARM64_V3 = Gate(
    rb"\x81.{2}\xb5\x80.{2}\xb4\x02\x20\x40\x39\x42.{2}\x37",
    rb"\x81.{2}\xb5\x80.{2}\xb4\x22\x00\x80\x52\x42.{2}\x37",
    b"\x22\x00\x80\x52",
    offset=8,
    desc="eligibility screen off (arm64, agy 1.5.6+ fetchPlanTier verdict)",
)

AGY_GATE = MultiGate(CLI_GATE_X64, CLI_GATE_ARM64, CLI_GATE_ARM64_V3,
                     desc="eligibility screen off")

# Antigravity.app language_server gate: force hasValidAuth=true.
# arm64: ldrb w3,[x0,#8]; tbz w3,#0,skip -> mov w3,#1; strb w3,[x0,#8]
_ARM64_TBZ_W3_BIT0 = rb"[\x03\x23\x43\x63\x83\xa3\xc3\xe3]..\x36"
_ARM64_TOKEN_SETUP = rb"(?:....){1,2}\x03\x10\x06\xa9"
MANAGER_GATE = MultiGate(
    Gate(
        rb"\x80\x78\x08\x00\x74.\x48\x8b.\x24.\x48\x89.\x60",
        rb"\xc6\x40\x08\x01\x90\x90\x48\x8b.\x24.\x48\x89.\x60",
        b"\xc6\x40\x08\x01\x90\x90",
        offset=0,
        desc="hasValidAuth=true (x64)",
    ),
    Gate(
        rb"\x03\x20\x40\x39" + _ARM64_TBZ_W3_BIT0 + _ARM64_TOKEN_SETUP,
        rb"\x23\x00\x80\x52\x03\x20\x00\x39" + _ARM64_TOKEN_SETUP,
        b"\x23\x00\x80\x52\x03\x20\x00\x39",
        offset=0,
        desc="hasValidAuth=true (arm64)",
    ),
    desc="hasValidAuth=true",
)


# ------------------------------------------------------------------ helpers --
@contextlib.contextmanager
def _mapped(path):
    with open(path, "rb") as f:
        if os.fstat(f.fileno()).st_size == 0:
            yield b""
            return
        mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        try:
            yield mm
        finally:
            mm.close()


def _locked(path):
    try:
        with open(path, "r+b"):
            return False
    except OSError:
        return True


def get_status(path, gate):
    """('patched'|'unpatched'|'unknown')."""
    if not path or not os.path.isfile(path):
        return "unknown"
    try:
        with _mapped(path) as d:
            kind, _, _ = gate.resolve(d)
            return kind
    except (LookupError, OSError):
        return "unknown"


def make_backup(path):
    """Snapshot of the pristine binary; refreshed when the app updated."""
    bak = path + BAK_EXT
    if os.path.exists(bak) and filecmp.cmp(path, bak, shallow=False):
        return
    if os.path.exists(bak):
        print(f"[*] backup is stale (app updated) — refreshing {os.path.basename(bak)}")
    shutil.copy2(path, bak)
    print(f"[+] backup: {bak} ({os.path.getsize(bak) // (1024 * 1024)} MB)")


def _app_bundle_of(path):
    """Nearest enclosing .app directory, or None."""
    p = os.path.dirname(os.path.realpath(path))
    while p and p != "/":
        if p.endswith(".app"):
            return p
        p = os.path.dirname(p)
    return None


def resign(path):
    """Ad-hoc re-sign: Apple Silicon SIGKILLs binaries whose signature is stale."""
    real = os.path.realpath(path)
    app = _app_bundle_of(real)
    cmd = ["codesign", "--force", "--deep", "--sign", "-", app] if app \
        else ["codesign", "--force", "--sign", "-", real]
    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True, timeout=120)
        subprocess.run(["xattr", "-d", "com.apple.quarantine", app or real],
                       capture_output=True, timeout=30)
        print(f"[*] re-signed ad-hoc: {os.path.basename(app or real)}")
    except Exception as e:
        print(f"[!] re-sign failed ({e}) — the binary may be killed on launch")


# -------------------------------------------------------------------- main --
def patch_one(label, path, gate):
    """True = ok (patched / already patched), False = needed patch but failed."""
    status = get_status(path, gate)
    if status == "patched":
        print(f"[i] {label}: already patched")
        return True
    if status == "unknown":
        print(f"[!] {label}: signature not found — unsupported binary version "
              f"(no signature for this build yet)")
        return False
    if _locked(path):
        print(f"[!] {label}: file is locked (uchg flag or app running) — skipped")
        return False

    with _mapped(path) as d:
        try:
            kind, offsets, g = gate.resolve(d)
        except LookupError as e:
            print(f"[!] {label}: {e}")
            return False
    if kind == "patched" or not offsets:
        print(f"[i] {label}: nothing to do")
        return True

    make_backup(path)
    with open(path, "r+b") as f:
        for off in offsets:
            f.seek(off)
            f.write(g.fix)
        f.flush()
        os.fsync(f.fileno())
    resign(path)
    print(f"[ok] {label}: patched {len(offsets)} gate(s) ({g.desc}) @ {path}")
    return True


def targets():
    out = []
    if os.path.isfile(AGY_BIN):
        out.append(("agy (CLI)", AGY_BIN, AGY_GATE))
    for ls in sorted(glob.glob(APP_BIN_GLOB)):
        out.append(("language_server (Antigravity.app)", ls, MANAGER_GATE))
    return out


def main():
    tgts = targets()
    if not tgts:
        print("[i] No Antigravity binaries found - nothing to do")
        return 0
    failures = []
    for label, path, gate in tgts:
        try:
            if not patch_one(label, path, gate):
                failures.append(label)
        except Exception as e:
            print(f"[!] {label}: {e}")
            failures.append(label)
    if failures:
        print()
        print("=" * 62)
        print("WARNING: antigravity patch FAILED for:")
        for label in failures:
            print(f"  - {label}")
        print("agy may hit the eligibility screen / lose Google models.")
        print("See antigravity-patch.md next to this script for how to")
        print("adapt signatures to the new binary version.")
        print("=" * 62)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
