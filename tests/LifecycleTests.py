"""Run the actual lifecycle scripts with OS boundaries confined to temporary fixtures."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

REPO = Path(__file__).resolve().parent.parent
CASES = ["clean-install", "upgrade", "failed-install-restore", "uninstall", "failed-uninstall-restore"]

with tempfile.TemporaryDirectory(prefix="sleepless-lifecycle-") as temporary:
    root = Path(temporary)
    for case in CASES:
        fixture = root / case
        fixture.mkdir()
        state = fixture / "state.json"
        events = fixture / "events.jsonl"
        app = fixture / "Applications/Sleepless.app"
        binaries = fixture / "bin"
        binaries.mkdir()
        running = case != "clean-install"
        state.write_text(json.dumps({"flag": int(running), "running": running, "watchdog": True, "grant": True}))
        adapter = binaries / "adapter"
        adapter.write_text('''#!/usr/bin/python3
import json, os, pathlib, shutil, sys
state=pathlib.Path(os.environ['FIXTURE_STATE']); value=json.loads(state.read_text())
name=pathlib.Path(sys.argv[0]).name; args=sys.argv[1:]
def event(label):
 with open(os.environ['FIXTURE_EVENTS'],'a') as out: out.write(json.dumps(label)+'\\n')
def save(): state.write_text(json.dumps(value))
if name=='pgrep': sys.exit(0 if value['running'] else 1)
if name=='osascript':
 if 'sudoers.d' in ' '.join(args):
  assert value['flag']==0 and not value['watchdog']; event('REMOVE_GRANT'); value['grant']=False
 else:
  if not value['running']: sys.exit(1) # Regression: resolving an absent bundle ID fails.
  assert value['flag']==0; event('QUIT'); value['running']=False
elif name=='SleeplessSafety':
 command=args[0]; event(command)
 if command=='quiesce':
  if os.environ.get('FAIL_RESTORE')=='1': sys.exit(1)
  value['flag']=0
 elif command=='remove-agent':
  assert value['flag']==0; value['watchdog']=False
elif name=='grant.sh':
 assert value['flag']==0; event('GRANT'); value['grant']=True
elif name=='watchdog-agent.sh':
 assert value['flag']==0; event('WATCHDOG'); value['watchdog']=True
elif name=='ditto':
 assert value['flag']==0; event('COPY')
 if pathlib.Path(args[1]).exists(): shutil.rmtree(args[1])
 shutil.copytree(args[0],args[1],symlinks=True)
elif name=='open':
 assert value['flag']==0; event('OPEN'); value['running']=True
elif name=='launchctl': event('LEGACY_AGENT')
elif name=='build.sh': event('BUILD')
else: raise AssertionError(name)
save()
''')
        adapter.chmod(0o755)
        for name in ["pgrep", "osascript", "ditto", "open", "launchctl"]:
            (binaries / name).symlink_to(adapter)
        source = fixture / "source"
        resources = source / "build/Sleepless.app/Contents/Resources"
        resources.mkdir(parents=True)
        for path in [source / "build.sh", source / "grant.sh", resources / "SleeplessSafety", resources / "watchdog-agent.sh"]:
            path.symlink_to(adapter)
        if running:
            (app / "Contents/Resources").mkdir(parents=True)
            (app / "Contents/Resources/SleeplessSafety").symlink_to(adapter)
        env = dict(os.environ, FIXTURE_STATE=str(state), FIXTURE_EVENTS=str(events),
                   HOME=str(fixture / "home"), PATH=str(binaries) + ":/usr/bin:/bin")
        if "failed-" in case:
            env["FAIL_RESTORE"] = "1"
        script = REPO / ("uninstall.sh" if "uninstall" in case else "install.sh")
        text = script.read_text().replace("/Applications/Sleepless.app", str(app))
        for command in ["pgrep", "osascript", "ditto"]:
            text = text.replace("/usr/bin/" + command, str(binaries / command))
        text = text.replace("/bin/launchctl", str(binaries / "launchctl"))
        target = (app / "Contents/Resources/uninstall.sh") if "uninstall" in case else (source / "install.sh")
        target.write_text(text)
        result = subprocess.run(["/bin/bash", str(target)], input="y\n", text=True,
                                capture_output=True, env=env, timeout=10)
        recorded = [json.loads(line) for line in events.read_text().splitlines()]
        final = json.loads(state.read_text())
        if "failed-" in case:
            assert result.returncode != 0, result.stdout + result.stderr
            assert final["flag"] == 1 and final["watchdog"] and final["grant"]
            assert not any(v in recorded for v in ["QUIT", "COPY", "remove-agent", "REMOVE_GRANT"]), recorded
            if "uninstall" in case:
                assert app.exists()
        else:
            assert result.returncode == 0, result.stdout + result.stderr
            assert final["flag"] == 0
            if case == "uninstall":
                assert not app.exists() and not final["watchdog"] and not final["grant"]
                assert recorded.index("quiesce") < recorded.index("remove-agent") < recorded.index("REMOVE_GRANT")
            else:
                assert app.exists() and final["watchdog"] and final["grant"]
                assert recorded.index("quiesce") < recorded.index("GRANT") < recorded.index("COPY") < recorded.index("WATCHDOG")
                if case == "clean-install":
                    assert "QUIT" not in recorded
        print("PASS lifecycle script: " + case)
print("5 lifecycle integration cases passed")
