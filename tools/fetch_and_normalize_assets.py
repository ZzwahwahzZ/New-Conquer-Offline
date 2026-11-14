#!/usr/bin/env python3
import os,re,json,hashlib,shutil,subprocess,zipfile
from pathlib import Path
from datetime import datetime,timezone
from urllib.parse import urlparse,urljoin,unquote
import requests
from huggingface_hub import HfApi,hf_hub_download
from imperial_extra_sources import discover_3dassets, discover_hanok_pack, discover_imperial_china_pack
from opengameart_sources import discover_opengameart, discover_quaternius
from new_asset_sources import discover_smithsonian, discover_kenney_nature, discover_sketchfab, discover_polygonal_mind, discover_innerscene_curated, discover_github_open_assets
ROOT=Path.cwd(); OUT=ROOT/"assets/wuxia_imperial_pack"; RAW=ROOT/".asset_work/raw"
HF_REPO=os.getenv("HF_REPO_ID","ZzwahwahzZ/clash-of-legends-terrain-assets"); PREFIX="assets/wuxia_imperial_pack"
S=requests.Session(); S.headers.update({"User-Agent":"NewConquerOffline-AssetPipeline/1.0 (GitHub Actions; asset audit)"})
TERMS={"architecture":["chinese temple","imperial palace","imperial chinese palace","ceremonial hall","gate tower","moon gate","palace wall","covered walkway","water pavilion","arched stone bridge","asian house","asian shop","chinese gate","watchtower","stone bridge","pagoda","asian architecture","stone wall","fort wall","city wall"],"ornaments":["dragon statue","dragon roof finial","guardian lion","guardian lion pair","bronze tripod cauldron","stone incense burner","garden lantern","silk lantern","bronze bell","ceremonial drum","stone fountain","chinese lantern","torch"],"nature":["willow tree","pine tree","bonsai pine","bamboo","bamboo clump","plum tree blossom","lotus cluster","rockery outcrop","peony planter","bush","shrub"],"pbr":["ornamental paving","paving stones","stone","marble","red roof tile","wood"]}
MISSING={k:list(v) for k,v in TERMS.items()}; COVERED={k:[] for k in TERMS}; DISC=[]; DOWN=[]; OK=[]; ERR=[]; REJECTED=[]; SKIPPED=[]; VERIFIED=[]; EXISTING_HASHES=set()
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
   if isinstance(v,dict) and any(isinstance(v.get(field),str) for field in ("url","downloadLink","rawLink","downloadUrl")): yield v
   else: yield from leaves(v)
 elif isinstance(x,list):
  for v in x: yield from leaves(v)
def polyhaven():
 assets=getj("https://api.polyhaven.com/assets",{"type":"models"})
 for aid,m in assets.items():
  if aid in {"pine_tree_01","weed_plant_02"} or aid in {x.get("id") for x in DISC}: continue
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
    if asset_id and asset_id in {x.get("id") for x in DISC}: continue
    if not asset_id: continue
    urls=download_urls(it.get("downloads",{}))
    # Only download complete archives; the archive retains all source maps and metadata.
    urls=[u for u in urls if ".zip" in u.lower()]
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
# Match complete concepts, including source-pack context. Avoid substring traps such as
# "dandelion" -> "lion" and "longhouse" -> "house".
BLACKLIST = re.compile(
 r"\b(?:ufo|jet|ski|safari|african|cruis\w*|ship|boat|yacht|marina|"
 r"church|gothic|cathedral|car|modern|sci[ _-]?fi|space|robot|gun|tank|"
 r"viking|longship|caravan|campsite|lawn|mowing|simulator|ocean|sea|"
 r"jellyfish|wildlife|outback|polar|lighthouse|golf course|"
 r"park and playground|christmas|halloween|radio telescope|"
 r"mythic underworld|olympus|griffin airmail|medieval|western|fantasy mmo)\b", re.I)
LION = re.compile(r"\blions?\b", re.I)
CATEGORY_RULES = {
 "palaces_and_temples": r"\b(?:pagoda|chinese temple|asian temple|japanese temple|korean temple|chinese palace|imperial palace|water pavilion|lotus pond pavilion|ceremonial hall)\b",
 "houses_and_shops": r"\b(?:(?:chinese|asian|japanese|traditional|wooden|timber|hanok|east asian)\s+){1,2}(?:(?:town|village|street|courtyard)\s+)?(?:house|shop|shopfront|storefront|inn|building)\b|\b(?:market stall|teahouse|tea house|inn|asian shop|chinese shop|wooden shopfront)\b",
 "gates_walls_bridges": r"\b(?:moon gate|chinese gate|palace gate|gate tower|watchtower|city wall|palace wall|stone wall|fort wall|arched stone bridge|arch bridge|stone bridge|courtyard entry arch)\b",
 "statues_and_props": r"\b(?:dragon|stone lion|guardian lion|lantern|incense burner|cauldron|brazier|bronze bell|ceremonial drum|altar|throne|folding screen|scroll rack|hanging scroll|floor cushion|inkstone|water dropper|tea set|tea table|guqin|calligraphy|parasol|banner|pennant|weapon rack|training dummy|fountain|komainu|onigawara|statue|ornament|storage chest|writing desk)\b",
 "nature": r"\b(?:bamboo|plum tree|willow tree|pine tree|cherry blossom|cherry tree|bonsai|lotus|peony|rockery|shrub|tree clump|blossom|reed clump|bluebell|fern clump|tussock grass|spinifex|grass clump|orchard tree|cattail|tall grass|maple|oak|birch|cedar|spruce|fir|cypress|tree|plant|flower|grass|fern|rock|boulder|moss|mushroom|reed|water lily|vine|ivy|root|log|stump|cliff|hill|mountain)\b",
 "pbr_materials": r"\b(?:marble|stone|tile|roof tile|wood|timber|pbr|texture)\b",
}
def _flatten_text(value):
 if isinstance(value, dict):
  return " ".join(_flatten_text(v) for v in value.values())
 if isinstance(value, (list, tuple, set)):
  return " ".join(_flatten_text(v) for v in value)
 if isinstance(value, (str, int, float)):
  return str(value)
 return ""
def record_text(record):
 # Include tags, description and nested API metadata so parent-pack context is not lost.
 fields=("id","name","title","source","source_url","download_url","tags","description",
         "api_metadata","pack","category","filename")
 return re.sub(r"[_-]+", " ", " ".join(_flatten_text(record.get(k, "")) for k in fields)).lower()
def identity_text(record, filename=""):
 # Include model identity and API taxonomy, but not broad search-query matches.
 fields=("id","name","title","source_url","api_metadata","pack","category","tags","description")
 text=" ".join(_flatten_text(record.get(k, "")) for k in fields)
 return re.sub(r"[_-]+", " ", text + " " + str(filename)).lower()

def is_architecture_candidate(record, filename=""):
 # Candidate identity comes from the asset itself, not a broad parent category tag.
 text=" ".join(_flatten_text(record.get(k,"")) for k in ("name","title","id"))+" "+str(filename)
 text=re.sub(r"[_-]+"," ",text).lower()
 return bool(re.search(r"\b(?:house|homes?|shops?|shopfront|storefront|market stall|teahouse|tea house|inn|pavilion|village building|buildings?)\b",text,re.I))

def rejected_asset(record):
 text=record_text(record)
 if BLACKLIST.search(text): return True
 if LION.search(text) and not re.search(r"\b(?:stone|guardian)\s+lions?\b", text): return True
 return False
def asset_category(record, filename=""):
 if record.get("target_category") in CATEGORY_RULES: return record["target_category"]
 if record.get("kind") == "pbr" or record.get("source") == "ambientCG" or any(c=="pbr" for c,t in record.get("matches",[])): return "pbr_materials"
 raw_name=_flatten_text(record.get("name") or record.get("title") or "")
 primary=re.sub(r"\s*\([^)]*\)", " ", raw_name)
 if not primary.strip(): primary=str(filename or "")
 primary=re.sub(r"[_-]+", " ", primary).lower()
 context=record_text(record)
 asian_context=bool(re.search(r"\b(?:chinese|asian|japanese|korean|hanok|wuxia|imperial|east asian)\b",context,re.I))
 if record.get("pack") == "korean-hanok-village-and-street":
  if re.search(r"\b(?:village gate house|gate house|village wall|boundary wall|wall straight|wall corner|wall end pier|stone street|stepped lane)\b",primary,re.I): return "gates_walls_bridges"
  if re.search(r"\b(?:persimmon|pine tree|bamboo|pond|stepping stones|garden tree)\b",primary,re.I): return "nature"
  if re.search(r"\b(?:house|outbuilding|market stall|shop|room module|post and beam|roof|roof tile|plinth|maru floor|floor module|frame|eave|rafter|door|window|chimney|flue|hearth|courtyard|street|lane|ground module)\b",primary,re.I): return "houses_and_shops"
  return "statues_and_props"
 if record.get("pack") == "imperial-china-palace-and-garden":
  if re.search(r"\b(?:ceremonial hall|water pavilion|lotus pond pavilion|walled palace courtyard|palace courtyard)\b",primary,re.I): return "palaces_and_temples"
  if re.search(r"\b(?:gate tower|palace wall|moon gate|covered walkway|arched stone bridge|terrace step|balustrade|column|bracket|roof cassette|roof ridge|courtyard paving|terrace platform|screen door)\b",primary,re.I): return "gates_walls_bridges"
  if re.search(r"\b(?:rockery|lotus|bamboo|plum tree|bonsai|peony|pond|stepping stone|garden stone bench)\b",primary,re.I): return "nature"
  return "statues_and_props"
 if asian_context and re.search(CATEGORY_RULES["statues_and_props"],primary,re.I): return "statues_and_props"
 if asian_context and re.search(CATEGORY_RULES["gates_walls_bridges"],primary,re.I): return "gates_walls_bridges"
 if asian_context and re.search(CATEGORY_RULES["houses_and_shops"],primary,re.I): return "houses_and_shops"
 if asian_context and re.search(r"\b(?:palace|temple|shrine|pavilion|ceremonial hall)\b",primary,re.I): return "palaces_and_temples"
 if re.search(CATEGORY_RULES["palaces_and_temples"],primary,re.I): return "palaces_and_temples"
 if re.search(CATEGORY_RULES["nature"],primary,re.I): return "nature"
 if record.get("candidate_only") and is_architecture_candidate(record,filename): return "houses_and_shops"
 return None

def strict_filter_self_test():
 cases=[
  ({"id":"motor-cruiser","name":"Motor cruiser with flybridge (Marina and Yacht Club)"},True,None),
  ({"id":"california-sea-lion","name":"california sea lion (Ocean Animals)"},True,None),
  ({"id":"lions-mane","name":"lions mane jellyfish (Ocean Giants)"},True,None),
  ({"id":"viking-longhouse","name":"Longhouse Gable End (Viking Age Longhouse and Longship)"},True,None),
  ({"id":"boundary-tree","name":"Boundary Tree Clump (Caravan Park and Campsite)"},True,None),
  ({"id":"dandelion","name":"Dandelion clump (Lawn Mowing Simulator Kit)"},True,None),
  ({"id":"dandelion-safe","name":"Dandelion flower"},False,"nature"),
  ({"id":"guardian-lion","name":"Guardian Lion Pair (Imperial China Palace and Garden)"},False,"statues_and_props"),
  ({"id":"hanging-scroll","name":"Hanging Scroll Pair (Imperial China Palace and Garden)"},False,"statues_and_props"),
  ({"id":"floor-cushion","name":"Floor Cushion Set (Imperial China Palace and Garden)"},False,"statues_and_props"),
  ({"id":"inkstone","name":"Inkstone and Water Dropper (Imperial China Palace and Garden)"},False,"statues_and_props"),
  ({"id":"imperial-courtyard","name":"Walled palace courtyard and lotus garden (Imperial China Palace and Garden)"},False,"palaces_and_temples"),
  ({"id":"palace-gate","name":"Palace Wall Moon Gate (Imperial China Palace and Garden)"},False,"gates_walls_bridges"),
  ({"id":"bamboo","name":"Bamboo Clump (Imperial China Palace and Garden)"},False,"nature"),
  ({"id":"asian-house","name":"Traditional Asian House"},False,"houses_and_shops"),
  ({"id":"wooden-village-house","name":"Wooden Village House","source":"3DAssets.dev","api_metadata":{"tags":"traditional east asian"}},False,"houses_and_shops"),
  ({"id":"wooden-shopfront","name":"Wooden Shopfront","source":"3DAssets.dev","api_metadata":{"tags":"chinese traditional"}},False,"houses_and_shops"),
  ({"id":"hanok-main-house","name":"Hanok Main House","source":"3DAssets.dev","pack":"korean-hanok-village-and-street"},False,"houses_and_shops"),
  ({"id":"hanok-market","name":"Market Stall With Awning","source":"3DAssets.dev","pack":"korean-hanok-village-and-street"},False,"houses_and_shops"),
  ({"id":"hanok-gate","name":"Village Gate House","source":"3DAssets.dev","pack":"korean-hanok-village-and-street"},False,"gates_walls_bridges"),
  ({"id":"hanok-bamboo","name":"Bamboo Clump","source":"3DAssets.dev","pack":"korean-hanok-village-and-street"},False,"nature"),
  ({"id":"hanok-lantern","name":"Hanging Lantern","source":"3DAssets.dev","pack":"korean-hanok-village-and-street"},False,"statues_and_props"),
  ({"id":"imperial-hall","name":"Ceremonial Hall","source":"3DAssets.dev","pack":"imperial-china-palace-and-garden"},False,"palaces_and_temples"),
  ({"id":"imperial-gate","name":"Gate Tower","source":"3DAssets.dev","pack":"imperial-china-palace-and-garden"},False,"gates_walls_bridges"),
  ({"id":"imperial-bridge","name":"Arched Stone Bridge","source":"3DAssets.dev","pack":"imperial-china-palace-and-garden"},False,"gates_walls_bridges"),
  ({"id":"imperial-roof","name":"Roof Cassette Hip","source":"3DAssets.dev","pack":"imperial-china-palace-and-garden"},False,"gates_walls_bridges"),
  ({"id":"imperial-lotus","name":"Lotus Cluster","source":"3DAssets.dev","pack":"imperial-china-palace-and-garden"},False,"nature"),
  ({"id":"imperial-lantern","name":"Hanging Silk Lantern","source":"3DAssets.dev","pack":"imperial-china-palace-and-garden"},False,"statues_and_props"),
  ({"id":"generic-house","name":"Wooden House","candidate_only":True},False,"houses_and_shops"),
  ({"id":"simple-building","name":"Simple Building","candidate_only":True},False,"houses_and_shops"),
  ({"id":"oga-pbr","name":"PBR Marble and Tile Texture Set","source":"OpenGameArt","matches":[("pbr","marble and tile")]},False,"pbr_materials"),
  ({"id":"viking-longhouse","name":"Viking Longhouse"},True,None),
  ({"id":"western-medieval","name":"Western Medieval House"},True,None),
  ({"id":"modern-apartment","name":"Modern Apartment Building"},True,None),
  ({"id":"church","name":"Church Building"},True,None),
  ({"id":"western-dragon","name":"Western Dragon With Wings Spread (Dragons and Wyverns)"},True,None),
  ({"id":"generic-temple","name":"Modular Temple Model"},False,None),
  ({"id":"medieval-temple","name":"Medieval Stone Temple"},True,None),
  ({"id":"western-court","name":"Palace Audience House (Royal Court and Throne Palace)"},True,None),
 ]
 failures=[]
 for rec,should_reject,should_category in cases:
  actual_reject=rejected_asset(rec)
  actual_category=asset_category(rec)
  if actual_reject!=should_reject or (not should_reject and actual_category!=should_category):
   failures.append({"record":rec,"rejected":actual_reject,"category":actual_category,
                    "expected_rejected":should_reject,"expected_category":should_category})
 license_cases=[("CC0 1.0",True),("CC BY 4.0",True),("OGA-BY 3.0",True),("CC BY-SA 4.0",True),("MIT",True),("BSD-3-Clause",True),("Zlib",True),("WTFPL",True),("Unlicense",True),("Public Domain",True),("GPL 3.0",True),("CC BY-NC 4.0",False),("CC BY-ND 4.0",False),("unknown free license",False)]
 for license_value,expected in license_cases:
  if license_allowed(license_value)!=expected: failures.append({"license":license_value,"expected":expected,"actual":license_allowed(license_value)})
 if failures: raise RuntimeError("Strict asset/license filter self-test failed: "+json.dumps(failures,ensure_ascii=False))
 print("STRICT_FILTER_SELF_TEST PASS",len(cases),"cases")
def license_allowed(value):
 text=str(value or "").strip().lower().replace("_","-").replace("–","-")
 if any(x in text for x in ("by-nc","by-nd","noncommercial","non-commercial","no derivatives","no-derivatives")): return False
 if re.search(r"\bcc[- ]?by[- ]?sa[- ]?(?:3\.0|4\.0)\b",text): return True
 if re.search(r"\b(?:cc0|public domain|public-domain|unlicense|wtfpl|mit|zlib|bsd(?:-2|-3)?(?:-clause)?|oga[- ]by\s*(?:3\.0|4\.0)|cc[- ]?by(?![- ]?sa))\b",text): return True
 if re.search(r"\bgpl[- ]?(?:2|3)(?:\.0)?(?:[- ]?(?:only|or-later))?\b",text): return True
 return False
def license_class(value):
 text=str(value or "").strip().lower().replace("_","-").replace("–","-")
 if "by-sa" in text or "by sa" in text or "gpl" in text: return "reciprocal"
 if "cc0" in text or "public domain" in text or "unlicense" in text or "wtfpl" in text: return "public-domain"
 if "mit" in text or "bsd" in text or "zlib" in text: return "permissive"
 if "oga-by" in text or "cc-by" in text or "cc by" in text: return "attribution"
 return "unclassified"
def license_url_for(value):
 text=str(value or "").strip().lower().replace("_","-")
 if "cc0" in text: return "https://creativecommons.org/publicdomain/zero/1.0/"
 if "oga-by" in text: return "https://opengameart.org/content/oga-by-30-faq"
 if "by-sa" in text or "by sa" in text:
  version=next((v for v in ("4.0","3.0") if v in text),None)
  return "https://creativecommons.org/licenses/by-sa/"+version+"/" if version else ""
 if "cc-by" in text or "cc by" in text:
  version=next((v for v in ("4.0","3.0","2.5","2.0","1.0") if v in text),"4.0")
  return "https://creativecommons.org/licenses/by/"+version+"/"
 if "mit" in text: return "https://opensource.org/license/mit/"
 if "bsd-2" in text: return "https://opensource.org/license/bsd-2-clause/"
 if "bsd" in text: return "https://opensource.org/license/bsd-3-clause/"
 if "zlib" in text: return "https://opensource.org/license/zlib/"
 if "wtfpl" in text: return "http://www.wtfpl.net/txt/copying/"
 if "unlicense" in text: return "https://unlicense.org/"
 if "gpl" in text:
  version="2" if re.search(r"gpl[- ]?2",text) else "3"
  return "https://www.gnu.org/licenses/old-licenses/gpl-"+version+".0.html"
 if "public domain" in text: return "https://creativecommons.org/publicdomain/mark/1.0/"
 return ""
def filter_candidates():
 global DISC, DOWN
 accepted=[]
 for record in DOWN:
  if not license_allowed(record.get("license")):
   REJECTED.append({"asset":record.get("id"),"stage":"license_filter","reason":"License is missing or outside the explicitly permitted open-license allow-list"})
  elif rejected_asset(record) or (not asset_category(record) and not (record.get("candidate_only") and is_architecture_candidate(record))):
   REJECTED.append({"asset":record.get("id"),"stage":"strict_identity_filter","reason":"Rejected by blacklist/identity filter"})
  else:
   record["license_class"]=license_class(record.get("license"))
   record["license_url"]=record.get("license_url") or license_url_for(record.get("license"))
   accepted.append(record)
 DOWN[:] = accepted
 accepted_ids={x.get("id") for x in accepted}
 DISC[:] = [x for x in DISC if x.get("id") in accepted_ids]
 print("STRICT_FILTER",json.dumps({"discovered":len(DISC),"retained":len(DOWN)},ensure_ascii=False))
def process():
 for r in DOWN:
  if r.get("id") == "weed_plant_02": continue
  try:
   p=Path(r["raw"]); fs=[]
   if p.suffix.lower()==".zip" or zipfile.is_zipfile(p):
    d=RAW/"unpacked"/safe(r["id"]); d.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(p) as z:
     for n in z.namelist():
      q=Path(n)
      if not q.is_absolute() and ".." not in q.parts: z.extract(n,d)
    fs=list(d.rglob("*"))
   elif p.suffix.lower()==".7z":
    import py7zr
    d=RAW/"unpacked"/safe(r["id"]); d.mkdir(parents=True,exist_ok=True)
    with py7zr.SevenZipFile(p,mode="r") as z: z.extractall(path=d)
    fs=list(d.rglob("*"))
   else: fs=[p]
   is_pbr = r["source"]=="ambientCG" or any(c=="pbr" for c,t in r.get("matches",[]))
   if is_pbr:
    dest=(OUT/"reciprocal"/"textures" if r.get("license_class")=="reciprocal" else OUT/"textures")/safe(r["id"]); dest.mkdir(parents=True,exist_ok=True); copied=[]
    for src in fs:
     if src.is_file() and src.suffix.lower() in (".jpg",".jpeg",".png",".tif",".tiff",".exr"):
      target=dest/src.name
      if not target.exists(): shutil.copy2(src,target)
      copied.append(str(target))
    names=[Path(x).name.lower() for x in copied]
    has_color=any(("color" in n or "albedo" in n or "basecolor" in n or "diff" in n) for n in names)
    has_normal=any("normal" in n for n in names)
    has_rough=any(("rough" in n or "roughness" in n) for n in names)
    if not (has_color and has_normal and has_rough):
     shutil.rmtree(dest,ignore_errors=True)
     raise ValueError("Incomplete PBR set; required Albedo/Color, Normal and Roughness maps")
    OK.append({**r,"kind":"pbr","files":copied,"dimensions_m":None,"validation":{"maps":[Path(x).name for x in copied],"color":has_color,"normal":has_normal,"roughness":has_rough}})
    for c,t in r["matches"]:
     if t not in COVERED.setdefault(c,[]): COVERED[c].append(t)
    continue
   models=[x for x in fs if x.is_file() and x.suffix.lower() in (".blend",".glb",".gltf",".fbx",".obj",".dae",".stl",".ply")]
   priority={".glb":0,".gltf":1,".blend":2,".fbx":3,".obj":4,".dae":5,".stl":6,".ply":7}
   models.sort(key=lambda x:(priority.get(x.suffix.lower(),99),str(x).lower()))
   if r.get("source") == "Quaternius" and any(c=="architecture" for c,t in r.get("matches",[])):
    models=[x for x in models if is_architecture_candidate({"id":x.name,"name":x.name},x.name)
            and not rejected_asset({"id":r.get("id",""),"name":x.name,"source":r.get("source"),"source_url":r.get("source_url"),"pack":r.get("pack","")})]
   elif r.get("source") == "Quaternius" and any(c=="nature" for c,t in r.get("matches",[])):
    nature_tokens=("tree","rock","bush","grass","fern","flower","plant","mushroom","stump","log","leaf","cactus","reed","foliage","shrub","blossom","cherry","pine","willow","maple","birch")
    models=[x for x in models if any(token in x.stem.lower() for token in nature_tokens)]
   if r.get("source") == "Kenney":
    nature_tokens=("tree","rock","bush","grass","fern","flower","plant","mushroom","stump","log","leaf","cactus","reed","foliage","shrub")
    models=[x for x in models if any(token in x.stem.lower() for token in nature_tokens)]
   if models:
    for i,src in enumerate(models[:80]):
     model_rec=dict(r)
     if r.get("source") == "Kenney":
      model_rec.update({"id":r["id"]+"-"+safe(src.stem),"name":src.stem.replace("_"," ").replace("-"," ").title(),
                        "target_category":"nature","matches":[("nature",src.stem)],"candidate_only":True})
     base_dir=(OUT/"reciprocal"/"candidates" if model_rec.get("candidate_only") else OUT/"reciprocal"/"models") if model_rec.get("license_class")=="reciprocal" else (OUT/"candidates"/"models" if model_rec.get("candidate_only") else OUT/"models")
     suffix=("_"+str(i)) if i and r.get("source")!="Kenney" else ""
     dst=base_dir/(safe(model_rec["id"])+suffix+".glb"); dst.parent.mkdir(parents=True,exist_ok=True)
     m=blender(src,dst)
     normalized_hash=sha(dst)
     if normalized_hash in EXISTING_HASHES:
      dst.unlink(missing_ok=True); dst.with_suffix(".json").unlink(missing_ok=True)
      SKIPPED.append({"asset":model_rec["id"],"stage":"duplicate_sha256","reason":"Normalized GLB exactly matches an existing or newly accepted asset"})
      continue
     EXISTING_HASHES.add(normalized_hash)
     OK.append({**model_rec,"kind":"model","file":str(dst),"dimensions_m":m["dimensions_m"],"validation":m})
    for c,t in r["matches"]:
     if t not in COVERED.setdefault(c,[]): COVERED[c].append(t)
   elif r["source"]=="ambientCG":
    dest=(OUT/"reciprocal"/"textures" if r.get("license_class")=="reciprocal" else OUT/"textures")/safe(r["id"]); dest.mkdir(parents=True,exist_ok=True); copied=[]
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
 OUT.mkdir(parents=True,exist_ok=True); entries=[]; grouped={k:[] for k in CATEGORY_RULES}
 supplemental=[]
 # Preserve already-approved local assets; this run is additive, not a replacement.
 old_manifest_path=OUT/"manifest.json"
 if old_manifest_path.exists():
  try:
   old_assets=json.loads(old_manifest_path.read_text(encoding="utf-8")).get("assets",[])
   existing_paths=set()
   for old in old_assets:
    rel=old.get("file","")
    if not rel or not (OUT/rel).is_file() or rel in existing_paths: continue
    category=old.get("category")
    if category not in grouped: continue
    entries.append(old); grouped[category].append(old); existing_paths.add(rel)
  except Exception as exc:
   raise RuntimeError("Existing asset manifest is unreadable; refusing destructive rebuild: "+str(exc))
 candidate_paths=set()
 for r in OK:
  paths=r.get("files") or [r["file"]]
  if r.get("candidate_only"):
   for f in paths:
    p=Path(f)
    if not p.exists(): continue
    candidate_paths.add(p.relative_to(OUT).as_posix())
    supplemental.append({"asset_id":r.get("id"),"name":r.get("name"),"candidate_category":asset_category(r,p.name),
      "file":p.relative_to(OUT).as_posix(),"source":r.get("source"),"source_url":r.get("source_url"),
      "license":r.get("license"),"bytes":p.stat().st_size,"sha256":sha(p),
      "dimensions_m":r.get("dimensions_m"),"license_url":r.get("license_url") or license_url_for(r.get("license")),"license_class":r.get("license_class") or license_class(r.get("license")),"authors":r.get("authors") or {},"validation":r.get("validation")})
   continue
  for f in paths:
   p=Path(f); category=asset_category(r,p.name)
   if not category or rejected_asset({"id":r.get("id"),"name":r.get("name"),"source":r.get("source"),"source_url":r.get("source_url"),"matches":r.get("matches"),"tags":p.name}):
    continue
   aid=str(r.get("id","")).lower()
   style_group="imperial_chinese" if ("imperial-china-palace-and-garden" in aid or r.get("source") in {"Smithsonian Open Access","Polygonal Mind Lunar Year"} or r.get("id","").startswith("innerscene-buddhist-temple-pagoda")) else "korean_hanok" if "korean-hanok-village-and-street" in aid else "pbr_materials" if category=="pbr_materials" else "environmental"
   item={"asset_id":r["id"],"name":r["name"],"category":category,"style_group":style_group,"file":p.relative_to(OUT).as_posix(),"source":r["source"],"source_url":r["source_url"],"direct_download_url":r.get("download_url"),"license":r["license"],"license_url":r.get("license_url") or license_url_for(r["license"]),"license_class":r.get("license_class") or license_class(r["license"]),"authors":r["authors"],"dimensions_m":r.get("dimensions_m"),"bytes":p.stat().st_size,"sha256":sha(p),"validation":r["validation"]}
   entries.append(item); grouped[category].append(item)
 approved_paths={x["file"] for x in entries} | candidate_paths
 for stale in list(OUT.rglob("*")):
  if stale.is_file() and stale.relative_to(OUT).as_posix() not in approved_paths:
   stale.unlink()
 counts={k:len(v) for k,v in grouped.items()}
 style_counts={}
 for x in entries:
  bucket=style_counts.setdefault(x["style_group"],{})
  bucket[x["category"]]=bucket.get(x["category"],0)+1
 manifest={"schema_version":"1.0","generated_at_utc":datetime.now(timezone.utc).isoformat(),"blender_version":blenderver,"assets":entries}
 (OUT/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
 approved={"schema_version":"1.0","generated_at_utc":manifest["generated_at_utc"],"units":"model dimensions are measured GLB bounding boxes in meters; PBR textures have no physical dimensions","categories":{k:{"count":len(v),"assets":v} for k,v in grouped.items()},"style_group_counts":style_counts,"total_approved_files":len(entries),"supplemental_candidates":supplemental}
 (OUT/"imperial_approved_assets.json").write_text(json.dumps(approved,ensure_ascii=False,indent=2))
 source_counts={}
 for x in entries: source_counts[x.get("source","unknown")]=source_counts.get(x.get("source","unknown"),0)+1
 lines=["# Wuxia Imperial Asset Audit","","- Blender: "+blenderver,"- License allow-list: CC0, CC-BY, OGA-BY 3.0/4.0, CC-BY-SA 3.0/4.0, MIT, BSD-2/3-Clause, Zlib, WTFPL, Unlicense, Public Domain, GPL-2.0/3.0 for standalone art assets.","- Reciprocal assets (CC-BY-SA/GPL) are isolated under reciprocal/ and must retain their source license and notices.","- Normalization: source units converted/retained as metres, model ground rebased to Y=0, and geometry is not arbitrarily resized to a common bounding box.","- Discovered: "+str(len(DISC)),"- Downloaded: "+str(len(DOWN)),"- Validated source assets: "+str(len(OK)),"- Approved file entries: "+str(len(entries)), "- Category counts: "+json.dumps(counts,ensure_ascii=False),"- Source counts: "+json.dumps(source_counts,ensure_ascii=False),"- Style group/category breakdown: "+json.dumps(style_counts,ensure_ascii=False),"- Operational errors: "+str(len(ERR)),"- Strict identity-filter exclusions: "+str(len(REJECTED)),"- Skipped legacy failures: "+str(len(SKIPPED)),"","## Approved files"]
 lines += ["- "+x["category"]+" | "+x["file"]+" | "+x["license"]+" | "+x["source"]+" | "+str(x["dimensions_m"] or "PBR texture set") for x in entries]
 lines += ["","## Operational errors"]+["- "+x["asset"]+" ("+x["stage"]+"): "+x["reason"] for x in ERR] if ERR else ["","## Operational errors","- None"]
 lines += ["","## Strict identity-filter exclusions"]+["- "+x["asset"] for x in REJECTED] if REJECTED else ["","## Strict identity-filter exclusions","- None"]
 lines += ["","## Skipped legacy failures"]+["- "+x["asset"]+" ("+x["stage"]+"): "+x["reason"] for x in SKIPPED] if SKIPPED else ["","## Skipped legacy failures","- None"]
 lines += ["","## Supplemental architecture candidates","- Downloaded and normalized, but not approved for city placement until visual style review."]
 lines += ["- "+str(x["candidate_category"])+" | "+x["file"]+" | "+str(x["name"])+" | "+str(x["source"]) for x in supplemental]
 lines += ["","## Approval rules","- Core architecture requires clear classical East Asian identity for automatic approval.","- Generic wooden/village buildings are retained as visual-review candidates rather than discarded.","- Nature and environmental dressing are accepted by visual/object suitability, independent of source-pack theme.","- Explicit modern, western-medieval, Viking, vehicle, sci-fi and unrelated wildlife assets remain excluded."]
 (OUT/"ASSET_AUDIT_REPORT.md").write_text("\n".join(lines)+"\n")
 credits=["# Third-party asset credits","","Only files listed in imperial_approved_assets.json are credited."]
 for x in entries:
  authors=x.get("authors") or {}
  author_values=[str(v).strip() for v in authors.values() if v and str(v).strip().lower() not in {str(x.get("source","")).strip().lower(),"3dassets.dev","ambientcg","poly haven"}]
  creator=", ".join(dict.fromkeys(author_values)) if author_values else "Not individually credited by source"
  credits += ["","## "+x["file"],"- Category: "+x["category"],"- Style group: "+x.get("style_group","environmental"),"- Creator attribution: "+creator,"- Publisher/source: "+x["source"],"- Asset page: "+x["source_url"],"- Direct download: "+str(x.get("direct_download_url") or "not supplied by source; use asset page"),"- License: "+x["license"],"- License URL: "+str(x.get("license_url") or license_url_for(x["license"])),"- License class: "+str(x.get("license_class") or license_class(x["license"])),"- Normalization changes: converted/normalized to GLB; ground origin corrected to Y=0; source dimensions retained in metres.","- Distribution note: "+("kept in reciprocal/ with the applicable share-alike/GPL license; do not merge into proprietary source code" if (x.get("license_class") or license_class(x["license"]))=="reciprocal" else "retain this attribution/license notice when redistributing"),"- Dimensions (m): "+str(x["dimensions_m"] or "not applicable (PBR textures)"),"- SHA256: "+x["sha256"]]
 for x in supplemental:
  authors=x.get("authors") or {}
  creator=", ".join(str(v) for v in authors.values() if v) or "Repository/source publisher; verify individual creator on source page"
  credits += ["","## "+x["file"],"- Status: Supplemental visual-review candidate (not yet placed in the city)","- Name: "+str(x.get("name")),"- Creator/publisher: "+creator,"- Source: "+str(x.get("source")),"- Asset page: "+str(x.get("source_url")),"- License: "+str(x.get("license")),"- License URL: "+str(x.get("license_url") or license_url_for(x.get("license"))),"- License class: "+str(x.get("license_class") or license_class(x.get("license"))),"- Normalization changes: converted/normalized to GLB; ground origin corrected to Y=0; source dimensions retained in metres.","- SHA256: "+str(x.get("sha256"))]
 (ROOT/"CREDITS.md").write_text("\n".join(credits)+"\n")
 return entries
def upload(entries):
 token=os.getenv("HF_TOKEN","").strip()
 if not token: raise RuntimeError("HF_TOKEN missing; add a write-enabled token to GitHub Actions Secrets.")
 api=HfApi(token=token)
 try: api.repo_info(HF_REPO,repo_type="dataset")
 except Exception as e: raise RuntimeError("HF_TOKEN cannot access target dataset; verify write permission: "+str(e))
 api.upload_folder(folder_path=str(OUT),repo_id=HF_REPO,repo_type="dataset",path_in_repo=PREFIX,commit_message="Synchronize validated Wuxia imperial asset pack")
 # upload_folder is additive: explicitly remove stale files, but only below this exact prefix.
 expected_paths={PREFIX+"/"+p.relative_to(OUT).as_posix() for p in OUT.rglob("*") if p.is_file()}
 remote_paths=set(api.list_repo_files(repo_id=HF_REPO,repo_type="dataset"))
 stale_paths=sorted(p for p in remote_paths if p.startswith(PREFIX+"/") and p not in expected_paths)
 if stale_paths:
  api.delete_files(HF_REPO,stale_paths,repo_type="dataset",
                   commit_message="Remove stale files from synchronized Wuxia imperial asset pack")
 remaining_paths=set(api.list_repo_files(repo_id=HF_REPO,repo_type="dataset"))
 leftovers=sorted(p for p in remaining_paths if p.startswith(PREFIX+"/") and p not in expected_paths)
 if leftovers: raise RuntimeError("Stale files remain under Wuxia pack prefix: "+", ".join(leftovers[:30]))
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
 # Seed discovery with the existing manifest so source adapters can skip known asset IDs
 # before downloading them. Existing approved files are preserved by builddocs().
 existing_manifest=OUT/"manifest.json"
 if existing_manifest.exists():
  try:
   prior=json.loads(existing_manifest.read_text(encoding="utf-8"))
   existing_assets=prior.get("assets",[])
   EXISTING_HASHES.update(str(x.get("sha256")) for x in existing_assets if x.get("sha256"))
   DISC.extend({**x,"id":x.get("id") or x.get("asset_id")} for x in existing_assets if isinstance(x,dict) and (x.get("id") or x.get("asset_id")))
   print("EXISTING_ASSET_IDS_LOADED",len(existing_assets))
  except Exception as exc:
   raise RuntimeError("Cannot safely deduplicate against existing manifest: "+str(exc))
 ver=subprocess.check_output([os.getenv("BLENDER_BIN","blender"),"--version"],text=True).splitlines()[0]
 SKIPPED.extend([
  {"asset":"pine_tree_01","stage":"known_legacy_failure","reason":"Skipped before discovery; prior download exceeded the configured size limit"},
  {"asset":"weed_plant_02","stage":"known_legacy_failure","reason":"Skipped before discovery; prior normalization failed"}
 ])
 strict_filter_self_test(); discover_polygonal_mind(getj,fetch,safe,sha,RAW,DISC,DOWN,ERR,SKIPPED); discover_innerscene_curated(fetch,safe,sha,RAW,DISC,DOWN,ERR,SKIPPED); discover_smithsonian(getj,fetch,safe,sha,RAW,DISC,DOWN,ERR,SKIPPED); discover_kenney_nature(fetch,safe,sha,RAW,DISC,DOWN,ERR,SKIPPED); discover_sketchfab(S,getj,fetch,safe,sha,RAW,DISC,DOWN,ERR,SKIPPED); discover_github_open_assets(S,fetch,safe,sha,RAW,DISC,DOWN,ERR,SKIPPED); discover_imperial_china_pack(getj,fetch,safe,sha,RAW,DISC,DOWN,ERR); discover_hanok_pack(getj,fetch,safe,sha,RAW,DISC,DOWN,ERR); discover_3dassets(getj,fetch,safe,sha,RAW,DISC,DOWN,ERR); discover_opengameart(S,fetch,safe,sha,RAW,DISC,DOWN,ERR); discover_quaternius(S,fetch,safe,sha,RAW,DISC,DOWN,ERR); polyhaven(); ambientcg(); filter_candidates(); process(); entries=builddocs(ver)
 if not entries:
  print(json.dumps({"discovered":len(DISC),"downloaded":len(DOWN),"validated":len(OK),"missing":MISSING,"errors":ERR},ensure_ascii=False,indent=2))
  raise RuntimeError("No assets passed license and validation checks; see printed per-source diagnostics. No empty upload performed.")
 upload(entries)
 print(json.dumps({"blender":ver,"discovered":len(DISC),"downloaded":len(DOWN),"validated":len(OK),"verified_remote":VERIFIED,"missing":MISSING,"errors":ERR},ensure_ascii=False,indent=2))
if __name__=="__main__": main()
