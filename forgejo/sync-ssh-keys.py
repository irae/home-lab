import argparse
import base64
import getpass
import hashlib
import json
from pathlib import Path
import sys
from urllib.parse import quote, urlsplit
from urllib.request import HTTPRedirectHandler, ProxyHandler, Request, build_opener


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def public_key(line):
    fields = line.split()
    if len(fields) < 2 or not fields[0].startswith(('ssh-', 'ecdsa-', 'sk-')):
        raise ValueError('expected a plain OpenSSH public key without options')
    kind, encoded = fields[:2]
    blob = base64.b64decode(encoded, validate=True)
    length = int.from_bytes(blob[:4], 'big')
    if not length or blob[4:4 + length] != kind.encode() or len(blob) <= 4 + length:
        raise ValueError('invalid SSH public key')
    return f'{kind} {encoded}'


def managed_title(key):
    return 'home-lab:' + hashlib.sha256(key.encode()).hexdigest()[:24]


def main():
    parser = argparse.ArgumentParser(description='Sync lab SSH public keys into a Forgejo account')
    parser.add_argument('url', help='Forgejo base URL')
    parser.add_argument('--user', default='irae', help='target Forgejo account (default: irae)')
    parser.add_argument('--source', type=Path, default=Path('/home/irae/.ssh/authorized_keys'))
    parser.add_argument('--admin', action='store_true', help='use admin API for another account')
    parser.add_argument('--prune', action='store_true', help='remove stale keys managed by this script')
    args = parser.parse_args()
    url = urlsplit(args.url)
    if url.scheme not in ('http', 'https') or not url.hostname or url.username or url.query or url.fragment:
        parser.error('provide an HTTP(S) base URL without credentials, a query, or a fragment')
    desired = set()
    for number, line in enumerate(args.source.read_text().splitlines(), 1):
        if line.strip() and not line.lstrip().startswith('#'):
            try:
                desired.add(public_key(line))
            except ValueError as error:
                raise ValueError(f'{args.source}:{number}: {error}') from error
    if not desired:
        raise ValueError('refusing to sync an empty key list')

    token = (getpass.getpass('Forgejo API token: ') if sys.stdin.isatty() else sys.stdin.readline()).strip()
    if not token:
        raise ValueError('missing Forgejo API token')
    client = build_opener(ProxyHandler({}), NoRedirects())

    def api(path, method='GET', data=None):
        req = Request(args.url.rstrip('/') + '/api/v1' + path, method=method,
                      headers={'Authorization': 'token ' + token, 'Content-Type': 'application/json'},
                      data=None if data is None else json.dumps(data).encode())
        with client.open(req, timeout=10) as response:
            payload = response.read()
        return json.loads(payload) if payload else None

    account = api('/user')
    if args.admin:
        if not account.get('is_admin'):
            raise ValueError('token does not belong to a Forgejo admin')
        slug = quote(args.user, safe='')
        read_path = f'/users/{slug}/keys'
        write_path = f'/admin/users/{slug}/keys'
    else:
        if account['login'] != args.user:
            raise ValueError(f'token does not belong to {args.user}')
        read_path = write_path = '/user/keys'

    existing = []
    for page in range(1, 1001):
        batch = api(f'{read_path}?page={page}&limit=50')
        if not batch:
            break
        existing.extend((public_key(item['key']), item) for item in batch)
    else:
        raise ValueError('too many pages of SSH keys')

    missing = desired - {key for key, _ in existing}
    for key in sorted(missing):
        api(write_path, 'POST', {'key': key, 'title': managed_title(key)})
    stale = [item for key, item in existing if key not in desired and item.get('title') == managed_title(key)]
    if args.prune:
        for item in stale:
            api(f'{write_path}/{item["id"]}', 'DELETE')
    print(f'{args.user}: {len(desired)} source keys present ({len(missing)} added); '
          f'{len(stale)} stale managed keys {"removed" if args.prune else "left in place"}.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as error:
        sys.exit(f'SSH key sync failed: {error}')
