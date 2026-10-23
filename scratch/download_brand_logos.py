import urllib.request
import ssl
import re

ctx = ssl._create_unverified_context()
headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

url = 'https://brandfetch.com/alkofarma.com'
try:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, context=ctx) as resp:
        html = resp.read().decode('utf-8', errors='ignore')
        imgs = re.findall(r'https://cdn\.brandfetch\.io/[^\s"\'<>]+', html)
        print("Brandfetch cdn:", set(imgs))
except Exception as e:
    print(e)
