#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, os, re, shutil, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];DEFAULT_CONFIG=ROOT/'.sdi-dev.json';REQUIRED_GODOT_LABELS=('4.3','4.4.1','4.5.2','4.6.3','4.7')
def run(cmd,cwd=ROOT):print('+',' '.join(map(str,cmd)),flush=True);return subprocess.run(cmd,cwd=cwd,check=False).returncode
def py(script,*args):return [sys.executable,str(ROOT/script),*args]
def version():
 m=re.search(r'^version="([^"]+)"$',(ROOT/'addons/script_dependency_inspector/plugin.cfg').read_text(),re.M);return m.group(1)
def load(path):
 if not path.is_file():return {'godot':{},'media_godot':'4.7'}
 v=json.loads(path.read_text());v.setdefault('godot',{});v.setdefault('media_godot','4.7');return v
def save(path,v):path.write_text(json.dumps(v,indent=2,sort_keys=True)+'\n')
def mapping(v):
 if '=' not in v:raise argparse.ArgumentTypeError('Use VERSION=/path/to/Godot')
 l,p=v.split('=',1)
 if l not in REQUIRED_GODOT_LABELS:raise argparse.ArgumentTypeError('Unsupported Godot label')
 return l,Path(p).expanduser().resolve()
def godots(c,all_=True):
 out=[];missing=[]
 for l in REQUIRED_GODOT_LABELS:
  p=c.get('godot',{}).get(l)
  (out.append((l,Path(p).expanduser().resolve())) if p else missing.append(l))
 if all_ and missing:raise RuntimeError('Godot paths are not configured for: '+', '.join(missing))
 return out
def ev(p):
 try:r=subprocess.run([str(p),'--version'],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=30)
 except (OSError,subprocess.TimeoutExpired) as e:return f'ERROR: {e}'
 return r.stdout.strip() if r.returncode==0 else f'ERROR({r.returncode}): {r.stdout.strip()}'
def tool(n):
 p=Path(sys.executable).resolve().parent/n;return str(p) if p.is_file() else shutil.which(n)
def configure(a):
 c=load(a.config);g=c.setdefault('godot',{})
 for l,p in a.godot:g[l]=str(p)
 if a.media_godot:c['media_godot']=a.media_godot
 save(a.config,c);print('Wrote developer config:',a.config);return 0
def doctor(a):
 ok=True;print('Python:',sys.executable);print('Python version:',sys.version.split()[0]);s=importlib.util.find_spec('PIL')
 if s is None:ok=False;print('Pillow: MISSING (`from PIL import Image` is unavailable)');print(f'Install with: {sys.executable} -m pip install -r requirements-dev.txt')
 else:
  import PIL;print(f'Pillow: {PIL.__version__} ({PIL.__file__})')
 for n in ('gdformat','gdlint'):
  p=tool(n);print(f'{n}: {p or "MISSING"}');ok &= p is not None
 if not a.python_only:
  try:gs=godots(load(a.config))
  except RuntimeError as e:print(e);return 2
  for l,p in gs:
   o=ev(p);good=o.startswith(l);print(f'Godot {l}: {p} -> {o}'+('' if good else ' [VERSION MISMATCH]'));ok &= good
 return 0 if ok else 2
def quality(a):
 try:gs=[] if a.skip_godot else godots(load(a.config))
 except RuntimeError as e:print(e,file=sys.stderr);return 2
 r=run(py('tools/run_gdscript_quality.py','--check' if a.check else '--fix'))
 if r:return r
 r=run(py('tools/validate_static.py'))
 if r:return r
 bad=[]
 for l,g in gs:
  if run(py('tools/run_validation.py','--godot',str(g),'--output',str(ROOT/'validation-artifacts'/'dev'/l.replace('.','_')),'--skip-static')):bad.append(l)
 if bad:print('Quality failed for Godot: '+', '.join(bad),file=sys.stderr);return 1
 print('Quality workflow passed.');return 0
def assets(a):
 if a.build_only:return run(py('tools/build_asset_store_media.py')) or run(py('tools/validate_asset_store_media.py'))
 c=load(a.config);l=str(c.get('media_godot','4.7'));v=c.get('godot',{}).get(l)
 if not v:return 2
 cmd=py('tools/capture_asset_store_media.py','--godot',str(Path(v).resolve()))
 if a.skip_editor_navigation:cmd.append('--skip-editor-navigation')
 if a.resume:cmd.append('--resume-existing')
 return run(cmd)
def package(a):
 try:gs=godots(load(a.config))
 except RuntimeError as e:print(e,file=sys.stderr);return 2
 o=a.output.resolve();o.mkdir(parents=True,exist_ok=True)
 if run(py('tools/build_release.py','--output',str(o))):return 1
 v=version();add=o/f'script-dependency-inspector-addon-v{v}.zip';proj=o/f'script-dependency-inspector-godot4-project-v{v}.zip';med=o/f'script-dependency-inspector-asset-store-media-v{v}.zip'
 if run(py('tools/verify_release_artifacts.py','--addon',str(add),'--project',str(proj),'--media',str(med))):return 1
 bad=[]
 for l,g in gs:
  if run(py('tools/verify_packaged_addon.py','--addon',str(add),'--godot',str(g))):bad.append(l)
 if bad:print('Packaged add-on verification failed for Godot: '+', '.join(bad),file=sys.stderr);return 1
 print('Package workflow passed:',o);return 0
def handoff(a):
 cmd=py('tools/build_handoff.py')
 if a.base_ref:cmd+=['--base-ref',a.base_ref]
 if a.output:cmd+=['--output',str(a.output.resolve())]
 if a.allow_sensitive:cmd.append('--allow-sensitive')
 return run(cmd)
def parser():
 p=argparse.ArgumentParser();p.add_argument('--config',type=Path,default=DEFAULT_CONFIG);s=p.add_subparsers(dest='command',required=True)
 q=s.add_parser('configure');q.add_argument('--godot',action='append',default=[],type=mapping);q.add_argument('--media-godot',choices=REQUIRED_GODOT_LABELS);q.set_defaults(handler=configure)
 q=s.add_parser('doctor');q.add_argument('--python-only',action='store_true');q.set_defaults(handler=doctor)
 q=s.add_parser('quality');q.add_argument('--check',action='store_true');q.add_argument('--skip-godot',action='store_true');q.set_defaults(handler=quality)
 q=s.add_parser('assets');q.add_argument('--build-only',action='store_true');q.add_argument('--skip-editor-navigation',action='store_true');q.add_argument('--resume',action='store_true');q.set_defaults(handler=assets)
 q=s.add_parser('package');q.add_argument('--output',type=Path,default=ROOT/'dist');q.set_defaults(handler=package)
 q=s.add_parser('handoff');q.add_argument('--base-ref');q.add_argument('--output',type=Path);q.add_argument('--allow-sensitive',action='store_true');q.set_defaults(handler=handoff);return p
def main():a=parser().parse_args();return int(a.handler(a))
if __name__=='__main__':raise SystemExit(main())
