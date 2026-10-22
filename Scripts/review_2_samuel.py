#!/usr/bin/env python3
"""Apply the 2 Samuel quality review to source JSON."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parent
def load(p): return json.loads(p.read_text(encoding="utf-8"))
def save(p, x): p.write_text(json.dumps(x, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
def main():
    ip = ROOT / "chapter_insights/10_2_samuel.json"; x = load(ip)
    placements = {
      10:"David showed covenant kindness to Mephibosheth in chapter 9. Chapter 10 records the insult of David's messengers and the war with Ammon and Syria. Chapter 11 turns to David's sin with Bathsheba.",
      5:"Chapter 4 ended with Ish-bosheth's murder and David's rejection of political violence. Chapter 5 unites Israel under David, makes Jerusalem his capital, and records victories over the Philistines. Chapter 6 brings the ark to Jerusalem.",
      7:"David brought the ark to Jerusalem in chapter 6. In chapter 7, David wants to build a house for the ark, but the LORD promises to establish David's house instead. Chapter 8 records the victories that follow.",
      8:"The LORD promises David an enduring house in chapter 7. Chapter 8 records David's victories and the growth of his royal administration. Chapter 9 shows David's kindness to Jonathan's son.",
      18:"Absalom's revolt drives David from Jerusalem in chapter 17. Chapter 18 tells the battle, Absalom's death, and David's grief. Chapter 19 begins David's return to Jerusalem.",
      21:"Chapter 20 ended with Sheba's revolt put down. Chapter 21 records a famine, justice for the Gibeonites, and battles with Philistine giants. Chapter 22 gives David's song of deliverance.",
      24:"David's last words and mighty men appear in chapter 23. Chapter 24 records David's census, the plague that follows, and his altar at Araunah's threshing floor. The story leads into 1 Kings, where Solomon becomes king."
    }
    for n, text in placements.items(): x[f"2 Samuel {n}"]["whereWeAre"] = text
    x["2 Samuel 14"]["summary"] = x["2 Samuel 14"]["summary"].replace("2 Samuel 14:21–24,2 Samuel 14:28", "(2 Samuel 14:21–24, 28)")
    for n in (10,16,17,19,20,21): x[f"2 Samuel {n}"]["keyFigures"] = x[f"2 Samuel {n}"]["keyFigures"][:6]
    save(ip,x)
    hp=ROOT/"historical_moments/04_samuel.json"; h=load(hp)
    h["2 Samuel 17"]="During Absalom's rebellion, David crosses the Jordan and takes refuge at Mahanaim east of the river while Absalom stays in Jerusalem (2 Samuel 17:22–26)."
    h["2 Samuel 20"]="After David returns to Jerusalem, Sheba's revolt ends at Abel of Bethmaachah in Israel's far north (2 Samuel 20:14–22)."
    save(hp,h)
    cp=ROOT/"chapter_context/10_2_samuel.json"; c=load(cp)
    c["2 Samuel 17"]["audience"]="The first Israelites who heard this account knew Mahanaim as a place east of the Jordan. They heard how David's supporters supplied him while Absalom's rebellion continued."
    c["2 Samuel 20"]["audience"]="The first Israelites who heard this account knew Sheba's revolt threatened the restored kingdom. They heard how a wise woman saved her city by ending the revolt."
    save(cp,c)
    op=ROOT/"book_overviews/02_early_history.json"; o=load(op); b=o["2 Samuel"]
    b["author"]="Nathan and Gad are the traditional sources named for David's reign, though 2 Samuel does not name a single writer."
    b["audience"]="Israel and later readers reflecting on David's monarchy and the LORD's covenant with his house."
    b["purpose"]="To tell of David's reign, the LORD's covenant promise, and the grave cost of David's sin."
    save(op,o)
    sp=ROOT/"book_content/02_early_history.md"; s=sp.read_text(encoding="utf-8")
    start,end=s.index("# 2 Samuel"),len(s)
    section=s[start:end].replace("His people Israel", "his people Israel").replace("His servants are confused", "his servants are confused")
    sp.write_text(s[:start]+section+s[end:],encoding="utf-8")
if __name__=="__main__": main()
