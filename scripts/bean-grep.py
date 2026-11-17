#!/usr/bin/env python3
"""Stream real ripgrep matches to fzf; keep raw paths separate from display text."""
import base64
import json
import os
import shlex
import subprocess
import sys
import time


def raw(field):
    return field['text'].encode('utf-8') if 'text' in field else base64.b64decode(field['bytes'])


def display(value):
    text = value.decode('utf-8', 'replace').rstrip('\r\n')
    return ''.join(f'\\x{ord(char):02x}' if ord(char) < 32 or 127 <= ord(char) <= 159 else char for char in text)


def matches(query):
    if not query:
        return 0
    time.sleep(0.08)  # Debounce typing; fzf cancels superseded reload process groups.
    command = ['rg', '--no-config', '--json', '--hidden', '--fixed-strings', '--smart-case',
               '--no-require-git', '--glob=!.git', '--glob=!node_modules', '--glob=!.cache', '--', query, '.']
    with subprocess.Popen(command, cwd=os.environ['BEAN_SEARCH_ROOT'], stdout=subprocess.PIPE) as process:
        assert process.stdout is not None
        for line in process.stdout:
            event = json.loads(line)
            if event['type'] != 'match':
                continue
            data = event['data']
            path = raw(data['path'])
            number = data['line_number']
            column = data['submatches'][0]['start'] + 1
            payload = {'path': base64.b64encode(path).decode('ascii'), 'line': number, 'column': column}
            record = json.dumps(payload, separators=(',', ':')) + '\t' + display(path) + f':{number}:{column}  ' + display(raw(data['lines']))
            sys.stdout.buffer.write(record.encode('utf-8') + b'\0')
            sys.stdout.buffer.flush()
        status = process.wait()
    return 0 if status in (0, 1) else status


def ui(root, result, colours, header):
    os.chdir(root)
    os.environ['BEAN_SEARCH_ROOT'] = root
    for name in ('FZF_DEFAULT_OPTS', 'FZF_DEFAULT_OPTS_FILE', 'FZF_DEFAULT_COMMAND'):
        os.environ[name] = ''
    # fzf quotes {q} itself. Never interpolate query text or paths into shell code.
    reload = f'{shlex.quote(sys.executable)} {shlex.quote(os.path.abspath(__file__))} matches {{q}}'
    args = ['fzf', '--read0', '--print0', '--no-multi', '--disabled', '--layout=reverse',
            '--delimiter=\t', '--with-nth=2..', '--nth=2..', '--tabstop=4',
            '--border=none', '--no-separator', '--info=inline', '--highlight-line',
            '--prompt=Search> ', '--header=' + header, '--color=' + colours,
            '--bind=esc:abort,ctrl-j:down,ctrl-k:up',
            '--bind=start:reload:' + reload, '--bind=change:reload:' + reload]
    # Exec leaves fzf as Neovim's tracked job; cancellation stops the real UI.
    with open(result, 'wb') as output, open(os.devnull, 'rb') as empty:
        os.dup2(output.fileno(), 1)
        os.dup2(empty.fileno(), 0)
    os.execvp('fzf', args)


if __name__ == '__main__':
    if sys.argv[1] == 'matches':
        raise SystemExit(matches(sys.argv[2]))
    if sys.argv[1] == 'ui':
        ui(*sys.argv[2:])
    raise SystemExit('Expected matches QUERY or ui ROOT RESULT COLOURS HEADER')
