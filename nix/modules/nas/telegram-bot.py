import urllib.request
import urllib.parse
import json
import subprocess
import time

TOKEN = open('/run/secrets/telegram_token').read().strip()
CHAT_ID = int(open('/run/secrets/telegram_chat_id').read().strip())
BASE = f'https://api.telegram.org/bot{TOKEN}'


def api(method, params=None):
    url = f'{BASE}/{method}'
    data = urllib.parse.urlencode(params).encode() if params else None
    req = urllib.request.Request(url, data)
    with urllib.request.urlopen(req, timeout=35) as r:
        return json.loads(r.read())


def send(chat_id, text):
    for i in range(0, len(text), 4096):
        api('sendMessage', {
            'chat_id': chat_id,
            'text': text[i:i+4096],
            'parse_mode': 'HTML',
        })


def run(cmd):
    try:
        r = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=30
        )
        out = (r.stdout + r.stderr).strip()
        return out or '(no output)'
    except subprocess.TimeoutExpired:
        return 'Command timed out.'
    except Exception as e:
        return f'Error: {e}'


COMMANDS = {
    '/df':       ('Disk usage',           'df -h'),
    '/zpool':    ('ZFS pool status',      'zpool status'),
    '/smart':    ('SMART health summary',
                  "smartctl --scan | awk '{print $1}' | "
                  "xargs -I{} sh -c 'echo \"=== {} ===\"; smartctl -H {}'"),
    '/k3s':      ('Kubernetes pods',      'k3s kubectl get pods -A'),
    '/services': ('Key service status',
                  'for s in smbd vsftpd nfs-server smartd k3s; do'
                  ' printf "%-20s %s\\n" "$s" "$(systemctl is-active $s)";'
                  ' done'),
    '/uptime':   ('System uptime',        'uptime'),
    '/mem':      ('Memory usage',         'free -h'),
}


def handle(text):
    cmd = text.split()[0]
    if cmd == '/help':
        lines = ['<b>Available commands:</b>', '/help — this message']
        for c, (desc, _) in COMMANDS.items():
            lines.append(f'{c} — {desc}')
        return '\n'.join(lines)
    if cmd in COMMANDS:
        _, shell = COMMANDS[cmd]
        return f'<pre>{run(shell)}</pre>'
    return f'Unknown command: {cmd}\nTry /help'


def main():
    offset = 0
    print('Telegram bot started', flush=True)
    while True:
        try:
            result = api('getUpdates', {
                'offset': offset,
                'timeout': 30,
                'allowed_updates': ['message'],
            })
            for update in result.get('result', []):
                offset = update['update_id'] + 1
                msg = update.get('message', {})
                chat_id = msg.get('chat', {}).get('id')
                text = msg.get('text', '').strip()
                if chat_id != CHAT_ID:
                    continue
                if text.startswith('/'):
                    send(chat_id, handle(text))
        except Exception as e:
            print(f'Error: {e}', flush=True)
            time.sleep(5)


main()
