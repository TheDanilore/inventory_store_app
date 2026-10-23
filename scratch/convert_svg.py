import subprocess
import os

edge_path = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if not os.path.exists(edge_path):
    edge_path = r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"

abs_webp = os.path.abspath('assets/icons/brands/mk.webp').replace('\\', '/')
abs_png = os.path.abspath('assets/icons/brands/mk.png').replace('\\', '/')

html = f"""<!DOCTYPE html>
<html>
<body style="margin:0;padding:20px;background:white;display:flex;align-items:center;justify-content:center;height:100vh;">
<img src="file:///{abs_webp}" style="width:200px;" />
</body>
</html>"""

with open('scratch/mk.html', 'w', encoding='utf-8') as f:
    f.write(html)

abs_html = os.path.abspath('scratch/mk.html').replace('\\', '/')
subprocess.run([edge_path, '--headless', f'--screenshot={abs_png}', '--window-size=300,200', f'file:///{abs_html}'])
print('MK PNG:', os.path.getsize('assets/icons/brands/mk.png'))
