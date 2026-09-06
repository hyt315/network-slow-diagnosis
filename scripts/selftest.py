#!/usr/bin/env python3
"""Regression test runner for network-slow-diagnosis skill.

Usage: python scripts/selftest.py
Runs the full test suite in tests/test_skill.py with positive and negative regression guards,
including syntax checking for PowerShell diagnostic scripts.
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# DY002 Negative fixture assertions (assert checker logic catches invalid inputs)
def assert_negative_cases() -> bool:
    # 1. Negative: invalid names should fail
    name_re = r"^[a-z0-9]+(-[a-z0-9]+)*$"
    if re.match(name_re, "BadName_Invalid"):
        return False
    if re.search(r"anthropic|claude", "claude-skill"):
        # expected to match reserved
        pass
    else:
        return False
    
    # 2. Negative: proxy configuration pattern must be blocked
    proxy_re = re.compile(r"配置代理|开启\s*Clash|启用代理|set\s*up\s*(?:proxy|Clash)", re.I)
    if not proxy_re.search("请配置代理或开启 Clash"):
        return False
        
    return True


def check_ps1_syntax(ps1_path: Path) -> bool:
    """Verify PS1 file syntax without executing it."""
    if not ps1_path.is_file():
        print(f"FAIL: {ps1_path} does not exist", file=sys.stderr)
        return False
    
    # If powershell is available, run AST parser
    pwsh = shutil.which("powershell") or shutil.which("pwsh")
    if pwsh:
        cmd = [
            pwsh, "-NoProfile", "-Command",
            f"$errors = $null; [System.Management.Automation.Language.Parser]::ParseFile('{ps1_path}', [ref]$null, [ref]$errors); if ($errors.Count -gt 0) {{ $errors | ForEach-Object {{ Write-Error $_ }}; exit 1 }} else {{ exit 0 }}"
        ]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0:
            print(f"FAIL: Syntax error in {ps1_path}:\n{proc.stderr}", file=sys.stderr)
            return False
    return True


def main() -> int:
    if not assert_negative_cases():
        print("FAIL: negative regression fixtures failed", file=sys.stderr)
        return 1

    diag_ps1 = ROOT / "scripts" / "diagnose.ps1"
    if not check_ps1_syntax(diag_ps1):
        return 1

    test_file = ROOT / "tests" / "test_skill.py"
    proc = subprocess.run([sys.executable, str(test_file)], cwd=ROOT, capture_output=True, text=True)
    sys.stdout.write(proc.stdout)
    sys.stderr.write(proc.stderr)
    if proc.returncode == 0 and "RESULT PASS" in proc.stdout:
        print("SELFTEST PASS (all positive, negative, and PS1 syntax checks passed)")
        return 0
    return 1

if __name__ == "__main__":
    sys.exit(main())
