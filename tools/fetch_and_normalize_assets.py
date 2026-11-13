#!/usr/bin/env python3
import os,re,json,hashlib,shutil,subprocess,zipfile
from pathlib import Path
from datetime import datetime,timezone
from urllib.parse import urlparse,urljoin,unquote
import requests
from huggingface_hub import HfApi,hf_hub_download
from imperial_extra_sources import discover_3dassets
from opengameart_sources import discover_opengameart
ROOT=Path.cwd(); OUT=ROOT/"assets/wuxia_imperial_pack"; RAW=ROOT/".asset_work/raw"
HF_REPO=os.getenv("HF_REPO_ID","ZzwahwahzZ/clash-of-legends-terrain-assets"); PREFIX="assets/wuxia_imperial_pack"
S=requests.Session(); S.headers.update({"User-Agent":"NewConquerOffline-AssetPipeline/1.0 (GitHub Actions; asset audit)"})
TERMS={"architecture":["chinese temple","imperial palace","asian house","asian shop","chinese gate","watchtower","stone bridge","pagoda","asian architecture","stone wall","fort wall","city wall"],"ornaments":["dragon statue","guardian lion","stone fountain","chinese lantern","torch"],"nature":["willow tree","pine tree","bamboo","bush","shrub"],"pbr":["ornamental paving","paving stones","stone","marble","red roof tile","wood"]}
MISSING={k:list(v) for k,v in TERMS.items()}; COVERED={k:[] for k in TERMS}; DISC=[]; DOWN=[]; OK=[]; ERR=[]; VERIFIED=[]
def sha(p):
 h=hashlib.sha256()
 with open(p,"rb") as f:
  for b in iter(lambda:f.read(1048576),b""): h.update(b)
 return h.hexdigest()
def getj(u,params=None):
 r=S.get(u,params=params,timeout=90); r.raise_for_status(); return r.json()
def safe(s): return re.sub(r"[^A-Za-z0-9._-]+","_",str(s))[:90] or "asset"
def fetch(u,p,limit=500*1024*1024):
 p.parent.mkdir(parents=True,exist_ok=True)
 with S.get(u,stream=True,timeout=(30,180)) as r:
  r.raise_for_status(); n=int(r.headers.get("content-length","0") or 0)
  if n and n>limit: raise ValueError("file exceeds size limit")
  with open(p,"wb") as f:
   total=0
   for c in r.iter_content(1048576):
    if c:
     total+=len(c)
     if total>limit: raise ValueError("download exceeds size limit")
     f.write(c)
 if not p.stat().st_size: raise ValueError("empty download")
 return p
def leaves(x):
 if isinstance(x,dict):
  for k,v in x.items():
   if isinstance(v,dict) and any(isinstance(v.get(k),str) for k in ("url","downloadLink","rawLink")): yield v
   else: yield from leaves(v)
 elif isinstance(x,list):
  for v in x: yield from leaves(v)
def polyhaven():
 assets=getj("https://api.polyhaven.com/assets",{"type":"models"})
 for aid,m in assets.items():
  hay=" ".join([aid,str(m.get("name","")),str(m.get("category",""))," ".join(m.get("categories",[]) if isinstance(m.get("categories"),list) else []),str(m.get("description",""))," ".join(m.get("tags",[]) if isinstance(m.get("tags"),list) else [])]).lower()
  hay=re.sub(r"[_-]+"," ",hay)
  matches=[(c,t) for c,ts in TERMS.items() if c!="pbr" for t in ts if re.search(r"(?<![a-z0-9])"+re.escape(t)+r"(?![a-z0-9])",hay)]
  if not matches: continue
  rec={"id":aid,"name":m.get("name",aid),"source":"Poly Haven","source_url":"https://polyhaven.com/a/"+aid,"license":"CC0 1.0","authors":m.get("authors",{}),"matches":matches}
  DISC.append(rec)
  try:
   files=getj("https://api.polyhaven.com/files/"+aid)
   choices=[]
   priority={".glb":0,".blend":1,".zip":2,".gltf":3,".fbx":4,".obj":5,".dae":6}
   for v in leaves(files):
    u=v["url"]; ext=Path(urlparse(u).path).suffix.lower()
    if ext in priority: choices.append((priority[ext],-int(v.get("size",0) or 0),u,ext))
   if not choices: raise ValueError("No supported model format in official API")
   choices.sort(key=lambda x:(x[0],x[1]))
   _,_,u,e=choices[0]
   if e==".gltf":
    p=RAW/"polyhaven"/safe(aid)/(safe(aid)+e); fetch(u,p)
    doc=json.loads(p.read_text(encoding="utf-8"))
    for group in ("buffers","images"):
     for item in doc.get(group,[]):
      uri=item.get("uri")
      if not uri or uri.startswith("data:"): continue
      parsed=urlparse(uri)
      rel=Path(unquote(parsed.path))
      if rel.is_absolute() or ".." in rel.parts: raise ValueError("Unsafe glTF dependency path: "+uri)
      dep=urljoin(u,uri); fetch(dep,p.parent/rel)
   else: p=fetch(u,RAW/"polyhaven"/(safe(aid)+e))
   DOWN.append({**rec,"download_url":u,"raw":str(p),"download_sha256":sha(p)})
  except Exception as e: ERR.append({"asset":aid,"stage":"download","reason":str(e)})
def ambientcg():
 # ambientCG v3 returns {assets:[...]}; request download metadata explicitly.
 # The named roof-tile asset is queried by exact ID so it is not lost to keyword ranking.
 queries=[("RoofingTiles013A","red roof tile"),("PavingStones036","paving stones"),("Marble012","marble"),("Wood096","wood")]
 def download_urls(node):
  found=[]
  if isinstance(node,dict):
   for k,v in node.items():
    if k.lower() in ("url","downloadlink","downloadurl","rawlink") and isinstance(v,str) and v.startswith("https://"):
     found.append(v)
    else: found.extend(download_urls(v))
  elif isinstance(node,list):
   for v in node: found.extend(download_urls(v))
  return found
 for aid,term in queries:
  try:
   data=getj("https://ambientcg.com/api/v3/assets",{"type":"material","id":aid,"limit":5,"include":"downloads,maps,title,url,tags"})
   items=data.get("assets",[]) if isinstance(data,dict) else []
   if not items:
    ERR.append({"asset":"ambientCG:"+aid,"stage":"discover","reason":"v3 API returned no matching material asset"})
    continue
   for it in items:
    asset_id=it.get("id")
    if not asset_id: continue
    urls=download_urls(it.get("downloads",{}))
    # Only download complete archives; the archive retains all source maps and metadata.
    urls=[u for u in urls if urlparse(u).path.lower().endswith(".zip")]
    if not urls:
     raise ValueError("No direct ZIP URL found in v3 downloads metadata")
    u=urls[0]
    rec={"id":asset_id,"name":it.get("title") or asset_id,"source":"ambientCG","source_url":"https://ambientcg.com/a/"+asset_id,"license":"CC0 1.0","authors":{"ambientCG":"ambientCG"},"matches":[("pbr",term)],"download_url":u}
    DISC.append(rec)
    p=fetch(u,RAW/"ambientcg"/(safe(asset_id)+".zip"))
    DOWN.append({**rec,"raw":str(p),"download_sha256":sha(p)})
  except Exception as e:
   ERR.append({"asset":"ambientCG:"+aid,"stage":"discover/download","reason":str(e)})
def blender(src,dst):
 cmd=[os.getenv("BLENDER_BIN","blender"),"-b","--python",str(ROOT/"tools/normalize_asset_blender.py"),"--","--input",str(src),"--output",str(dst)]
 x=subprocess.run(cmd,text=True,capture_output=True,timeout=900)
 output=(x.stdout or "")+"\n"+(x.stderr or "")
 meta=dst.with_suffix(".json")
 if x.returncode:
  raise RuntimeError("Blender exited with code "+str(x.returncode)+":\n"+output[-12000:])
 if not dst.exists() or not meta.exists():
  raise RuntimeError("Blender returned exit code 0 but output/validation metadata is missing. Expected GLB: "+str(dst)+" (exists="+str(dst.exists())+"), metadata: "+str(meta)+" (exists="+str(meta.exists())+"). Blender output:\n"+output[-12000:])
 return json.loads(meta.read_text())
def process():
 for r in DOWN:
  try:
   p=Path(r["raw"]); fs=[]
   if p.suffix.lower()==".zip":
    d=RAW/"unpacked"/safe(r["id"]); d.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(p) as z:
     for n in z.namelist():
      q=Path(n)
      if not q.is_absolute() and ".." not in q.parts: z.extract(n,d)
    fs=list(d.rglob("*"))
   else: fs=[p]
   models=[x for x in fs if x.is_file() and x.suffix.lower() in (".blend",".glb",".gltf",".fbx",".obj",".dae",".stl",".ply")]
   if models:
    for i,src in enumerate(models[:4]):
     dst=OUT/"models"/(safe(r["id"])+(("_"+str(i)) if i else "")+".glb"); dst.parent.mkdir(parents=True,exist_ok=True)
     m=blender(src,dst); OK.append({**r,"kind":"model","file":str(dst),"dimensions_m":m["dimensions_m"],"validation":m})
    for c,t in r["matches"]:
     if t not in COVERED.setdefault(c,[]): COVERED[c].append(t)
   elif r["source"]=="ambientCG":
    dest=OUT/"textures"/safe(r["id"]); dest.mkdir(parents=True,exist_ok=True); copied=[]
    for src in fs:
     if src.is_file() and src.suffix.lower() in (".jpg",".jpeg",".png",".tif",".tiff",".exr"):
      shutil.copy2(src,dest/src.name); copied.append(str(dest/src.name))
    names=[Path(x).name.lower() for x in copied]
    has_color=any(("color" in n or "albedo" in n or "basecolor" in n) for n in names)
    has_normal=any("normal" in n for n in names)
    has_rough=any("roughness" in n for n in names)
    if not (has_color and has_normal and has_rough):
     shutil.rmtree(dest,ignore_errors=True)
     raise ValueError("Incomplete PBR set; required Albedo/Color, Normal and Roughness maps")
    OK.append({**r,"kind":"pbr","files":copied,"dimensions_m":None,"validation":{"maps":[Path(x).name for x in copied]}})
    for c,t in r["matches"]:
     if t not in COVERED.setdefault(c,[]): COVERED[c].append(t)
  except Exception as e: ERR.append({"asset":r["id"],"stage":"normalize","reason":str(e)})
def builddocs(blenderver):
 OUT.mkdir(parents=True,exist_ok=True); entries=[]
 for category,terms in TERMS.items(): MISSING[category]=[t for t in terms if t not in COVERED.get(category,[])]
 for r in OK:
  paths=r.get("files") or [r["file"]]
  for f in paths:
   p=Path(f); entries.append({"asset_id":r["id"],"name":r["name"],"file":p.relative_to(OUT).as_posix(),"source":r["source"],"source_url":r["source_url"],"direct_download_url":r.get("download_url"),"license":r["license"],"authors":r["authors"],"downloaded_at_utc":datetime.now(timezone.utc).isoformat(),"dimensions_m":r.get("dimensions_m"),"bytes":p.stat().st_size,"sha256":sha(p),"validation":r["validation"]})
 manifest={"generated_at_utc":datetime.now(timezone.utc).isoformat(),"blender_version":blenderver,"assets":entries}
 (OUT/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
 lines=["# Wuxia Imperial Asset Audit","",f"- Blender: {blenderver}",f"- Discovered: {len(DISC)}",f"- Downloaded: {len(DOWN)}",f"- Locally validated: {len(OK)}",f"- Manifest file entries: {len(entries)}",f"- Errors: {len(ERR)}","","## Accepted files"]
 lines += [f"- {e['file']} | {e['license']} | {e['source']} | {e['bytes']} bytes | SHA256 {e['sha256']} | dimensions m: {e['dimensions_m'] or 'texture set'}" for e in entries]
 lines += ["","## Errors"]+[f"- {e['asset']} ({e['stage']}): {e['reason']}" for e in ERR] if ERR else ["","## Errors","- None"]
 lines += ["","## الأصول الناقصة المطلوبة"]+[f"- {k}: {', '.join(v) if v else 'تم العثور على أصل مرشح'}" for k,v in MISSING.items()]
 lines += ["","## Licensing","- Poly Haven models: publisher-declared CC0; unique User-Agent used.","- ambientCG materials: publisher-declared CC0 1.0.","- Assets without verified publisher licensing were not accepted."]
 (OUT/"ASSET_AUDIT_REPORT.md").write_text("\n".join(lines)+"\n")
 c=["# Third-party asset credits","","Only successfully downloaded and locally validated assets are listed."]
 for e in entries:
  c += ["", "## "+e["file"],"- Creator: "+(", ".join(e["authors"].keys()) if e["authors"] else e["source"]),"- Source: "+e["source_url"],"- Direct download: "+str(e["direct_download_url"] or "source page"),"- License: "+e["license"],"- Dimensions (m): "+str(e["dimensions_m"] or "not applicable"),"- SHA256: "+e["sha256"]]
 (ROOT/"CREDITS.md").write_text("\n".join(c)+"\n")
 return entries
def upload(entries):
 token=os.getenv("HF_TOKEN","").strip()
 if not token: raise RuntimeError("HF_TOKEN missing; add a write-enabled token to GitHub Actions Secrets.")
 api=HfApi(token=token)
 try: api.repo_info(HF_REPO,repo_type="dataset")
 except Exception as e: raise RuntimeError("HF_TOKEN cannot access target dataset; verify write permission: "+str(e))
 api.upload_folder(folder_path=str(OUT),repo_id=HF_REPO,repo_type="dataset",path_in_repo=PREFIX,commit_message="Upload validated Wuxia imperial asset pack")
 for p in [x for x in OUT.rglob("*") if x.is_file()]:
  name=PREFIX+"/"+p.relative_to(OUT).as_posix()
  remote=Path(hf_hub_download(repo_id=HF_REPO,repo_type="dataset",filename=name,token=token,force_download=True))
  if p.stat().st_size!=remote.stat().st_size or sha(p)!=sha(remote): raise RuntimeError("Remote SHA256/size mismatch: "+name)
  VERIFIED.append({"path":name,"bytes":p.stat().st_size,"sha256":sha(p)})
 report=OUT/"ASSET_AUDIT_REPORT.md"
 with open(report,"a") as f:
  f.write("\n## Hugging Face verification\n- Dataset: "+HF_REPO+"\n- Verified files before final report update: "+str(len(VERIFIED))+"\n")
  for x in VERIFIED: f.write("- "+x["path"]+" | "+str(x["bytes"])+" bytes | SHA256 "+x["sha256"]+"\n")
 api.upload_file(path_or_fileobj=str(report),path_in_repo=PREFIX+"/ASSET_AUDIT_REPORT.md",repo_id=HF_REPO,repo_type="dataset",token=token,commit_message="Publish final asset audit verification")
 remote=Path(hf_hub_download(repo_id=HF_REPO,repo_type="dataset",filename=PREFIX+"/ASSET_AUDIT_REPORT.md",token=token,force_download=True))
 if sha(report)!=sha(remote) or report.stat().st_size!=remote.stat().st_size:
  raise RuntimeError("Final audit report failed remote SHA256/size verification")
def main():
 if not shutil.which(os.getenv("BLENDER_BIN","blender")): raise RuntimeError("Blender executable missing")
 ver=subprocess.check_output([os.getenv("BLENDER_BIN","blender"),"--version"],text=True).splitlines()[0]
 discover_3dassets(getj,fetch,safe,sha,RAW,DISC,DOWN,ERR); discover_opengameart(S,fetch,safe,sha,RAW,DISC,DOWN,ERR); polyhaven(); ambientcg(); process(); entries=builddocs(ver)
 if not entries:
  print(json.dumps({"discovered":len(DISC),"downloaded":len(DOWN),"validated":len(OK),"missing":MISSING,"errors":ERR},ensure_ascii=False,indent=2))
  raise RuntimeError("No assets passed license and validation checks; see printed per-source diagnostics. No empty upload performed.")
 upload(entries)
 print(json.dumps({"blender":ver,"discovered":len(DISC),"downloaded":len(DOWN),"validated":len(OK),"verified_remote":VERIFIED,"missing":MISSING,"errors":ERR},ensure_ascii=False,indent=2))
if __name__=="__main__": main()
