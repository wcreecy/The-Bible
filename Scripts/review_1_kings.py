#!/usr/bin/env python3
"""Apply the 1 Kings quality review to source content."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parent
def load(p): return json.loads(p.read_text(encoding='utf-8'))
def save(p,x): p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main():
 p=ROOT/'chapter_insights/11_1_kings.json'; x=load(p)
 for n in range(1,23):
  k=f'1 Kings {n}'; summary=x[k]['summary'].split('. ',1)[0]
  prior='2 Samuel 24 ends with David buying Araunah\'s threshing floor.' if n==1 else f'Chapter {n-1} has just moved the story forward.'
  following='The account hands off to 2 Kings 1, where Ahaziah seeks help after his fall.' if n==22 else f'Chapter {n+1} continues the consequences of these events.'
  x[k]['whereWeAre']=f'{prior} {summary}. {following}'
 for n in (1,2,11,16): x[f'1 Kings {n}']['keyFigures']=x[f'1 Kings {n}']['keyFigures'][:6]
 x['1 Kings 2']['summary']=x['1 Kings 2']['summary'].replace('without requiring', 'without claiming')
 save(p,x)
 op=ROOT/'book_overviews/02_early_history.json'; o=load(op); b=o['1 Kings']
 b['author']='Jeremiah is the traditional author, though 1 Kings does not name its writer.'
 b['audience']='Israel and later readers learning why the united kingdom divided and how its kings answered the LORD.'
 b['purpose']='To trace Solomon’s reign, the division of the kingdom, and the LORD’s word through prophets such as Elijah.'
 save(op,o)
 sp=ROOT/'book_content/03_later_history.md'; s=sp.read_text(encoding='utf-8'); a=s.index('# 1 Kings'); z=s.index('# 2 Kings',a)
 section=s[a:z].replace(' His ',' his ').replace(' Him',' him')
 sp.write_text(s[:a]+section+s[z:],encoding='utf-8')
if __name__=='__main__': main()
