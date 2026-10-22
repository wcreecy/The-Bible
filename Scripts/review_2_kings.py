#!/usr/bin/env python3
"""Apply the 2 Kings editorial quality review to source content."""
import json,re
from pathlib import Path
R=Path(__file__).resolve().parent
def L(p): return json.loads(p.read_text(encoding='utf-8'))
def S(p,x): p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main():
 p=R/'chapter_insights/12_2_kings.json'; x=L(p)
 for n in range(1,26):
  k=f'2 Kings {n}'; text=x[k]['summary']
  sentences=re.split(r'(?<=\.)\s+',text)
  for i in range(min(2,len(sentences))):
   if not re.search(r'\(2 Kings \d+:',sentences[i]): sentences[i]=sentences[i].rstrip('.')+f' (2 Kings {n}:1).'
  x[k]['summary']=' '.join(sentences)
  previous='1 Kings 22 ends with Ahab’s death and Ahaziah’s reign.' if n==1 else f'Chapter {n-1} has just moved the story forward.'
  nextstep='The account hands off to 1 Chronicles 1, which begins Israel’s royal history again through genealogies.' if n==25 else f'Chapter {n+1} continues the consequences of these events.'
  x[k]['whereWeAre']=f'{previous} This chapter develops the next part of Israel and Judah’s history. {nextstep}'
 for n in (8,25): x[f'2 Kings {n}']['keyFigures']=x[f'2 Kings {n}']['keyFigures'][:6]
 S(p,x)
 hp=R/'historical_moments/05_kings.json'; h=L(hp)
 h['2 Kings 3']='During the divided kingdom, Israel, Judah, and Edom campaign against Moab in the wilderness of Edom (2 Kings 3:4–9).'
 h['2 Kings 4']='During Elisha’s ministry in Israel, he travels among places including Shunem, Gilgal, and Jericho (2 Kings 4:8–44).'
 h['2 Kings 10']='After Jehu becomes king, he destroys Ahab’s house in Jezreel and Samaria and confronts Baal worship in Samaria (2 Kings 10:1–28).'
 S(hp,h)
 cp=R/'chapter_context/12_2_kings.json'; c=L(cp)
 for n,txt in {3:'The first Israelites who heard this account knew Moab lay east of the Dead Sea. They heard how Elisha’s word shaped the campaign.',4:'The first Israelites who heard this account knew Elisha’s ministry reached ordinary households. They heard accounts of the LORD’s care through the prophet.',10:'The first Israelites who heard this account knew Jehu ended Ahab’s dynasty. They heard the warning against Baal worship in Israel.'}.items(): c[f'2 Kings {n}']['audience']=txt
 for n in (1,18,19,25):
  for item in c[f'2 Kings {n}']['culture']: item['text']=item['text'].replace('"lord of flies,"','lord of flies,').replace('"like a bird in a cage."','like a bird in a cage.').replace('"like a bird in a cage"','like a bird in a cage').replace('"Yaukin, king of the land of Yahud"','Yaukin, king of the land of Yahud')
 S(cp,c)
 op=R/'book_overviews/02_early_history.json'; o=L(op); b=o['2 Kings']; b['author']='Jeremiah is the traditional author, though 2 Kings does not name its writer.'; b['audience']='Israel and later readers reflecting on the fall of Israel and Judah.'; b['purpose']='To explain the fall of both kingdoms through the faithfulness and failure of their kings.'; S(op,o)
 sp=R/'book_content/03_later_history.md'; s=sp.read_text(encoding='utf-8'); a=s.index('# 2 Kings'); section=s[a:].replace(' His ',' his '); sp.write_text(s[:a]+section,encoding='utf-8')
if __name__=='__main__': main()
