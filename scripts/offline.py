"""Bundle the download page and app into one browser-openable file."""
from base64 import b64encode
from pathlib import Path
import re

site = Path("build/site")
html = (site / "index.html").read_text(encoding="utf-8")
css = (site / "greeting.css").read_text(encoding="utf-8")
html = html.replace('<link rel="stylesheet" href="greeting.css">', f"<style>{css}</style>")
for name in ("letter-strokes.js", "hanzi-strokes.js", "greeting.js", "zip.js", "configurator.js"):
    script = (site / name).read_text(encoding="utf-8")
    pattern = r'<script src="' + re.escape(name) + r'(?:\?[^"]+)?"></script>'
    html, replaced = re.subn(pattern, lambda _: f"<script>{script}</script>", html, count=1)
    if replaced != 1:
        raise ValueError(f"Script tag missing for {name}")
encoded = b64encode((site / "app-template.zip").read_bytes()).decode("ascii")
html = html.replace("</html>", f'<script id="app-template" type="application/octet-stream">{encoded}</script>\n</html>')
Path("build/Customize GPT Welcome.html").write_text(html, encoding="utf-8")
