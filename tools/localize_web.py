"""Localize only the generated Godot HTML shell; leave engine JS untouched."""
from pathlib import Path
import re,shutil
p=Path('exports/web/index.html')
s=p.read_text(encoding='utf-8')
s=s.replace('<html lang="en">','<html lang="zh-CN">')
s=re.sub(r'<title>.*?</title>','<title>零号设施 · 潜行逃生</title>',s)
s=s.replace('Your browser does not support the canvas tag.','当前浏览器不支持游戏画布，请使用新版桌面浏览器。')
s=s.replace('Your browser does not support JavaScript.','请启用浏览器的脚本功能后再运行游戏。')
s=s.replace('src="index.png" alt=""','src="escape.svg" alt="零号设施"')
s=s.replace('<progress id="status-progress">','<div id="status-caption"><strong>零号设施</strong><p>潜行逃生 · 正在连接设施…</p></div>\n<progress id="status-progress">')
style='''
#status {background:#08141e; font-family:system-ui,"Microsoft YaHei",sans-serif;}
#status-splash {width:96px!important;height:96px!important;top:27%;bottom:auto;left:0;right:0;margin:0 auto;}
#status-caption {position:absolute;top:46%;left:0;right:0;text-align:center;color:#e5edf0;}
#status-caption strong {font-size:32px;letter-spacing:3px;font-weight:600;}
#status-caption p {font-size:15px;color:#9cb6c1;margin-top:18px;}
#status-progress {bottom:27%;width:min(320px,60%);height:6px;accent-color:#ffad59;}
'''
s=s.replace('</style>',style+'\n</style>')
# Godot initializes the window title after the startup scene; localize that title too.
s=s.replace('重力快递 · 夜班潜行','零号设施 · 潜行逃生')
pattern=r'function displayFailureNotice\(err\) \{.*?\n\t\}\n\n\tconst missing'
replacement='''function displayFailureNotice(err) {
        console.error(err);
        const caption = document.getElementById('status-caption');
        if (caption) caption.style.display = 'none';
        setStatusNotice('暂时无法启动游戏。请刷新页面，或使用支持 WebGL 2.0 的新版桌面浏览器。');
        setStatusMode('notice');
        initializing = false;
    }

    const missing'''
s,n=re.subn(pattern,lambda _:replacement,s,flags=re.S)
if n!=1:raise RuntimeError('Unexpected Godot HTML shell; review localization before publishing')
p.write_text(s,encoding='utf-8')
shutil.copyfile('assets/ui/escape-mark.svg','exports/web/escape.svg')
print('Chinese branded Web loading screen installed',flush=True)

