"""Real installed-app acceptance against four visible native text windows on two displays.
Launch the TargetFixture executable with --edges first.
"""
import json, subprocess, time, re
from pathlib import Path
DRIVER = "/tmp/lens-native-driver"
BUNDLE = "studio.kamihi.mandarinlens.v31"  # Stable approved identity across 3.1 / 3.2.

def run(*args, check=True):
    return subprocess.run(args, check=check, capture_output=True, text=True).stdout

def key(code, option=False):
    run("osascript", "-e", 'tell application "System Events" to key code ' + str(code) + (" using option down" if option else ""))

def dump():
    return run(DRIVER, "--app", BUNDLE, "--window", "Quick lookup", "--absent-ok", "--dump", check=False)

results=[]
screens=json.loads(run(DRIVER,"--app",BUNDLE,"--screens"))
assert len(screens)>=2, "This acceptance run requires two connected displays"
for name, term, index in [("primary top left","beautiful",0),("primary bottom right","coffee",0),("external top right","coffee",1),("external bottom right","coffee",1)]:
    v=screens[index]["visible"]
    visible=tuple(v[k] for k in ["X","Y","Width","Height"])
    key(53)
    run(DRIVER,"--app","studio.kamihi.lens.targetfixture","--window",name,"--activate")
    time.sleep(.15)  # Wait for the source window to finish moving between Spaces.
    target=run(DRIVER,"--app","studio.kamihi.lens.targetfixture","--window",name,"--point",term)
    key(49, True)
    deadline=time.monotonic()+4
    while time.monotonic()<deadline:
        state=dump()
        if "AXStaticText " + term + "\n" in state: break
        time.sleep(.1)
    assert "AXStaticText " + term + "\n" in state, (name,state)
    time.sleep(.15)
    listed=json.loads(run(DRIVER,"--app",BUNDLE,"--frames"))
    panel=next(w for w in listed if w["title"].startswith("Quick lookup"))
    x,y,w,h=(panel["bounds"][k] for k in ["X","Y","Width","Height"])
    vx,vy,vw,vh=visible
    assert vx <= x and vy <= y and x+w <= vx+vw and y+h <= vy+vh, (name,panel,visible)
    results.append(dict(case=name,frame=[x,y,w,h],target=term,screen=index,scale=screens[index]["scale"]))
    key(53)
    deadline=time.monotonic()+1
    while time.monotonic()<deadline and "AXWindow Quick lookup" in dump():
        time.sleep(.02)
    assert "AXWindow Quick lookup" not in dump(), "Escape did not dismiss"
    deadline=time.monotonic()+1
    while True:
        front=run(DRIVER,"--app","studio.kamihi.lens.targetfixture")
        if "FRONTMOST studio.kamihi.lens.targetfixture" in front or time.monotonic()>=deadline:break
        time.sleep(.02)
    assert "FRONTMOST studio.kamihi.lens.targetfixture" in front
    print("PASS", name, "exact target", term, "panel", [x,y,w,h], "Escape/focus", flush=True)
Path("native/reports/final-display-frames.json").write_text(json.dumps(results,indent=2)+"\n")
