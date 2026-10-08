"""Which backend the Python live runners (tools/test-*.py) talk to.

Default: the app's backend, MaroonSocial/Resources/Backend.json (the live project).
Optional overrides, read from the environment:

  MAROON_API_URL  base URL that serves /functions/v1/<name> (and /auth/v1, /rest/v1 for the
                  runners that use them), e.g. a local proxy in front of the local stack
  MAROON_API_KEY  publishable (anon) key for that base URL

Set both or neither: a local URL with the live key (or the reverse) is refused before any
request is made. Every runner prints the host it targets before it creates anything.
With an override, cleanup receipts go to the temp directory (see receipt()), so a local run
never replaces the receipt of a run against the live project.
"""
import json, os, pathlib, sys, tempfile, urllib.parse

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = ROOT / 'MaroonSocial/Resources/Backend.json'
overridden = False


def load(config_path=None):
    """Return {'url', 'publishableKey', ...} for the runner and print the target host."""
    path = pathlib.Path(config_path) if config_path else DEFAULT_CONFIG
    config = dict(json.loads(path.read_text()))
    url = os.environ.get('MAROON_API_URL', '').strip()
    key = os.environ.get('MAROON_API_KEY', '').strip()
    if bool(url) != bool(key):
        sys.exit('Set MAROON_API_URL and MAROON_API_KEY together (or neither, for the backend in %s).' % path.name)
    global overridden
    overridden = bool(url)
    if url:
        config['url'], config['publishableKey'], source = url, key, 'MAROON_API_URL'
    else:
        source = path.name
    config['url'] = config['url'].rstrip('/')
    host = urllib.parse.urlsplit(config['url']).netloc or config['url']
    print('Target backend: %s (from %s)' % (host, source), file=sys.stderr, flush=True)
    return config


def receipt(path):
    """Path for a cleanup receipt: `path` for the default backend; with MAROON_API_URL set, the
    same file name prefixed with maroon-override- in the temp directory."""
    path = pathlib.Path(path)
    return pathlib.Path(tempfile.gettempdir()) / ('maroon-override-' + path.name) if overridden else path
