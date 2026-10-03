#!/usr/bin/env python3
from __future__ import annotations
import argparse, os, shutil, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
EXCLUDED_PARTS={'.git','.godot','dist','validation-artifacts','__pycache__'}
LINE_LENGTH=100
def gdscript_files():
 return [str(p.relative_to(ROOT)) for p in sorted(ROOT.rglob('*.gd')) if not any(x in EXCLUDED_PARTS for x in p.relative_to(ROOT).parts)]
def resolve_tool(name):
 d=Path(sys.executable).resolve().parent; cs=[d/name]
 if os.name=='nt': cs.insert(0,d/f'{name}.exe')
 return next((str(c) for c in cs if c.is_file()), shutil.which(name))
def run_required(name,args,label):
 exe=resolve_tool(name)
 if exe is None:
  print(f'Required GDScript quality tool is unavailable: {name}\nPython interpreter: {sys.executable}\nInstall with: {sys.executable} -m pip install -r requirements-dev.txt',file=sys.stderr); return 2
 r=subprocess.run([exe,*args],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,check=False)
 if r.stdout.strip(): print(r.stdout.rstrip())
 if r.returncode: print(f'{label} failed with exit status {r.returncode}.',file=sys.stderr); return r.returncode
 print(f'{label}: passed'); return 0
def main():
 p=argparse.ArgumentParser();m=p.add_mutually_exclusive_group();m.add_argument('--fix',action='store_true');m.add_argument('--check',action='store_true');a=p.parse_args();scripts=gdscript_files();args=['-l',str(LINE_LENGTH),*scripts];label=f'gdformat -l {LINE_LENGTH}'
 if not a.fix: args.insert(0,'--check');label+=' --check'
 r=run_required('gdformat',args,label);return r if r else run_required('gdlint',scripts,'gdlint')
if __name__=='__main__':raise SystemExit(main())
