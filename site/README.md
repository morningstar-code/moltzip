# Website

The MoltZip website, published by `.github/workflows/pages.yml` to https://morningstar-code.github.io/moltzip whenever `site/` changes on `main`. Static pages, no build step, no JavaScript, no requests to other sites.

| File | Purpose |
|---|---|
| `index.html` | The main page, in English |
| `es/index.html` | The main page, in Spanish |
| `verify.html` | Checksums of the latest release |
| `img/` | The animations (light, dark, English, Spanish) and the Open Graph image |
| `style.css` | All styles, light and dark |
| `404.html` | Page shown for unknown addresses |
| `favicon.svg` | Browser tab icon |
| `robots.txt`, `sitemap.xml` | For search engines |
| `_headers` | Security and cache headers for hosts that read it (not GitHub Pages) |

## Preview locally

```sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory site
```

## After each release

```sh
python3 tools/update-verify.py v0.3.0
```

That rewrites the release file table in `verify.html` from the release's `.sha256` files (it needs the GitHub CLI, signed in). Then update `softwareVersion` in the structured data of `index.html` and "Current version" in `llms.txt`. After any change to `style.css`, bump the `?v=` number where the pages link it.
