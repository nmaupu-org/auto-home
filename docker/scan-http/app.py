from flask import Flask, send_from_directory, render_template_string, abort
import os
from pathlib import Path
from datetime import datetime

app = Flask(__name__)
SCAN_DIR = "/scans"
FILES_PER_PAGE = 20

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Scan Viewer</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
        body {
            font-family: sans-serif;
            max-width: 600px;
            margin: 1rem auto;
            padding: 0.5rem;
            background: #f2f2f2;
            color: #333;
            font-size: 14px;
        }
        h1 {
            text-align: center;
            font-size: 1.25rem;
            margin-bottom: 1rem;
        }
        .file-row {
            display: flex;
            justify-content: space-between;
            padding: 0.4rem 0.2rem;
            border-bottom: 1px solid #ddd;
        }
        .file-row a {
            color: #007acc;
            text-decoration: none;
            word-break: break-word;
            max-width: 70%;
        }
        .file-row small {
            color: #666;
            white-space: nowrap;
        }
        .page-info {
            text-align: center;
            font-size: 13px;
            color: #555;
            margin-top: 1rem;
        }
        .nav {
            text-align: center;
            margin-top: 0.5rem;
        }
        .nav a {
            margin: 0 0.5rem;
            padding: 0.3rem 0.6rem;
            font-size: 13px;
            background: #0077cc;
            color: white;
            text-decoration: none;
            border-radius: 4px;
        }
        .nav a:hover {
            background: #005fa3;
        }
    </style>
</head>
<body>
    <h1>📄 Scan Viewer</h1>
    {% for row in rows %}
        <div class="file-row">
            <a href="/file/{{ row.name }}" target="_blank">{{ row.name }}</a>
            <small>{{ row.date }}</small>
        </div>
    {% endfor %}
    <div class="page-info">
        Page {{ page }} of {{ total_pages }}
    </div>
    <div class="nav">
        {% if page > 1 %}
        <a href="/page/{{ page - 1 }}">← Prev</a>
        {% endif %}
        {% if page != 1 %}
        <a href="/">🏠 Home</a>
        {% endif %}
        {% if page < total_pages %}
        <a href="/page/{{ page + 1 }}">Next →</a>
        {% endif %}
    </div>
</body>
</html>
"""

@app.route("/")
@app.route("/page/<int:page>")
def index(page=1):
    try:
        all_files = sorted(
            Path(SCAN_DIR).glob("*.pdf"),
            key=os.path.getctime,
            reverse=True
        )
        total_files = len(all_files)
        total_pages = (total_files + FILES_PER_PAGE - 1) // FILES_PER_PAGE

        if page < 1 or page > total_pages:
            abort(404)

        start = (page - 1) * FILES_PER_PAGE
        end = start + FILES_PER_PAGE
        files = all_files[start:end]

        rows = [
            {
                "name": f.name,
                "date": datetime.fromtimestamp(os.path.getmtime(f)).strftime("%Y-%m-%d %H:%M")
            }
            for f in files
        ]

        return render_template_string(HTML_TEMPLATE, rows=rows, page=page, total_pages=total_pages)

    except Exception as e:
        return f"Error: {str(e)}", 500

@app.route("/file/<filename>")
def file(filename):
    return send_from_directory(SCAN_DIR, filename)
