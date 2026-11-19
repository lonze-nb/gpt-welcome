"""Bundle the download page and app into one browser-openable file."""
from base64 import b64encode
from pathlib import Path

site = Path("build/site")
html = (site / "index.html").read_text(encoding="utf-8")
css = (site / "greeting.css").read_text(encoding="utf-8")
html = html.replace('<link rel="stylesheet" href="greeting.css">', f"<style>{css}</style>")
for name in ("greeting.js", "zip.js", "configurator.js"):
    script = (site / name).read_text(encoding="utf-8")
    html = html.replace(f'<script src="{name}"></script>', f"<script>{script}</script>")
encoded = b64encode((site / "app-template.zip").read_bytes()).decode("ascii")
html = html.replace("</html>", f'<script id="app-template" type="application/octet-stream">{encoded}</script>\n</html>')
Path("build/Customize GPT Welcome.html").write_text(html, encoding="utf-8")
