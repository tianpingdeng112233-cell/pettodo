import re, html, sys

def inline(t):
    codes=[]
    def keep(m):
        codes.append(m.group(1)); return f"\x00{len(codes)-1}\x00"
    t=re.sub(r'`([^`]+)`', keep, t)
    t=html.escape(t)
    t=re.sub(r'!\[([^\]]*)\]\(([^)]+)\)', lambda m:f'<img src="{m.group(2)}" alt="{m.group(1)}">', t)
    t=re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', t)
    t=re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', t)
    t=re.sub(r'(?<!\*)\*([^*\n]+)\*(?!\*)', r'<em>\1</em>', t)
    t=re.sub(r'\x00(\d+)\x00', lambda m:'<code>'+html.escape(codes[int(m.group(1))])+'</code>', t)
    return t

CAP = re.compile(r'^\*\*(Figure|图)\s')

def convert(md):
    out=[]; buf=[]; quote=[]; cap=[None]
    def flush():
        if not buf: return
        raw=' '.join(buf).strip(); buf.clear()
        h=inline(raw)
        if '<img ' in h:
            # 图注与图片常在同一段(中间无空行):拆成 figcaption + img
            m2=re.match(r'^(.*?)(<img [^>]*>)(.*)$', h, re.S)
            capt=m2.group(1).strip(); img=m2.group(2); rest=m2.group(3).strip()
            if not capt and cap[0]: capt=cap[0]; cap[0]=None
            out.append('<figure>' + (f'<figcaption>{capt}</figcaption>' if capt else '') + img + '</figure>')
            if rest: out.append(f'<p>{rest}</p>')
        elif CAP.match(raw) and raw.rstrip().endswith('**'):
            cap[0]=h
        else:
            out.append(f'<p>{h}</p>')
    def flushq():
        if quote:
            out.append('<blockquote>'+inline(' '.join(quote))+'</blockquote>'); quote.clear()
    for line in md.split('\n'):
        s=line.rstrip()
        if s.startswith('> '): flush(); quote.append(s[2:]); continue
        flushq()
        if not s.strip(): flush(); continue
        m=re.match(r'^(#{1,4})\s+(.*)$', s)
        if m: flush(); out.append(f'<h{len(m.group(1))}>{inline(m.group(2))}</h{len(m.group(1))}>'); continue
        if re.match(r'^-{3,}$', s.strip()): flush(); out.append('<hr>'); continue
        buf.append(s.strip())
    flush(); flushq()
    return '\n'.join(out)

CSS="""
@page { size: A4; margin: 20mm 18mm; }
body { font-family: "Times New Roman", Georgia, serif; font-size: 11.5pt; line-height: 1.55; color:#1a1a1a; margin:0; }
h1 { font-size: 20pt; margin: 0 0 4pt; line-height: 1.25; }
h2 { font-size: 14.5pt; margin: 22pt 0 6pt; padding-top: 4pt; border-top: 1px solid #d8d8d8; }
h3 { font-size: 12.5pt; margin: 16pt 0 5pt; }
h4 { font-size: 11.5pt; margin: 13pt 0 4pt; font-style: italic; font-weight: 600; }
h2,h3,h4 { page-break-after: avoid; }
p { margin: 0 0 8pt; text-align: justify; hyphens: auto; }
a { color:#14508c; text-decoration:none; }
code { font-family:"SF Mono",Menlo,monospace; font-size:9.5pt; background:#f2f2f2; padding:0.5pt 3pt; border-radius:3px; }
blockquote { margin:10pt 0; padding:8pt 12pt; background:#f7f7f5; border-left:3px solid #bbb; font-size:10.5pt; }
blockquote p { margin:0; }
figure { margin:12pt 0 16pt; text-align:center; page-break-inside:avoid; break-inside:avoid; }
figcaption { font-weight:600; font-size:10.5pt; text-align:left; margin:0 0 6pt; }
figure img { max-height:135mm; max-width:44%; width:auto; height:auto; border:1px solid #ddd; border-radius:6px; }
hr { border:0; border-top:1px solid #e0e0e0; margin:16pt 0; }
"""
md=open(sys.argv[1]).read()
open(sys.argv[2],'w').write(
 f'<!doctype html><html><head><meta charset="utf-8"><title>PetTodo Mid-term Report</title>'
 f'<style>{CSS}</style></head><body>{convert(md)}</body></html>')
