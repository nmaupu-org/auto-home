from flask import Flask, send_from_directory, render_template_string, request, abort
import os
from pathlib import Path
from datetime import datetime

app = Flask(__name__)
SCAN_DIR = "/scans"
FILES_PER_PAGE = 20

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

        links = ""
        for f in files:
            mtime = datetime.fromtimestamp(os.path.getmtime(f)).strftime("%Y-%m-%d %H:%M")
            links += f'<li><a href="/file/{f.name}">{f.name}</a> <small>{mtime}</small></li>'

        # Navigation
        nav = ""
        if page > 1:
            nav += f'<a href="/page/{page - 1}">Previous</a> '
        if page < total_pages:
            nav += f'<a href="/page/{page + 1}">Next</a>'

        html = f"<ul>{links}</ul><div>{nav}</div>"
        return render_template_string(html)

    except Exception as e:
        return f"Error: {str(e)}", 500

@app.route("/file/<filename>")
def file(filename):
    return send_from_directory(SCAN_DIR, filename)
