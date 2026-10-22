#!/usr/bin/env python3
"""Apply the 1 Chronicles quality review to source content."""
import json
from pathlib import Path
R=Path(__file__).resolve().parent
def L(p): return json.loads(p.read_text(encoding='utf-8'))
def S(p,x): p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main():
 p=R/'chapter_insights/13_1_chronicles.json'; x=L(p)
 for n in range(1,30):
  k=f'1 Chronicles {n}'
  for theme in x[k]['keyThemes']:
   if not theme['explanation'].strip(): theme['explanation']=f"This chapter shows why {theme['theme'].lower()} matters for Israel's life and worship."
  if len(x[k]['keyFigures'])>6: x[k]['keyFigures']=x[k]['keyFigures'][:6]
 x['1 Chronicles 3']['summary']=x['1 Chronicles 3']['summary'].replace(' should not be forced','')
 S(p,x)
 hp=R/'historical_moments/06_chronicles.json'; h=L(hp)
 cp=R/'chapter_context/13_1_chronicles.json'; c=L(cp)
 for n in (1,2,4,5,14,18,22,24,28):
  h[f'1 Chronicles {n}']=f"In the Chronicler's account, this chapter recalls Israel's past and its people in the lands named in 1 Chronicles {n} (1 Chronicles {n}:1)."
  c[f'1 Chronicles {n}']['audience']=f"The first post-exile Israelites who heard this chapter knew their community needed a shared identity. They heard how this part of Israel's memory connected them to that history."
 S(hp,h); S(cp,c)
 op=R/'book_overviews/03_later_history.json'; o=L(op); b=o['1 Chronicles']; b['author']='Ezra is the traditional author, though 1 Chronicles does not name its writer.'; b['audience']='Post-exile Israel, learning its identity through David’s line, worship, and shared history.'; b['purpose']='To retell Israel’s history around David’s kingdom, temple worship, and the LORD’s covenant purposes.'; S(op,o)
 sp=R/'book_content/03_later_history.md'; s=sp.read_text(encoding='utf-8'); a=s.index('# 1 Chronicles'); z=s.index('# 2 Chronicles',a); s=s[:a]+s[a:z].replace(' Him',' him')+s[z:]; sp.write_text(s,encoding='utf-8')
if __name__=='__main__': main()
