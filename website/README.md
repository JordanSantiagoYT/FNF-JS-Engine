# Phoenix Engine documentation site

[Docusaurus 3](https://docusaurus.io/) site documenting the FNF Phoenix Engine codebase.
Published to GitHub Pages by `.github/workflows/docs.yml`.

## Run it

```bash
cd website
npm install
npm start          # dev server (regenerates the reference first)
npm run build      # production build into website/build (also runs lint:docs)
npm run serve      # serve the production build
npm run lint:docs  # check the markdown conventions the site needs to render
```

Node 20+ is required.

## What is generated

Two parts of the site are produced from the Haxe sources and are **git-ignored** — never
edit them by hand:

| Command | Reads | Writes |
|---|---|---|
| `npm run gen:api` | `source/**/*.hx` | `docs/reference/**` — one page per type, one index per package |
| `npm run gen:scripts` | `source/psychlua/**` | `docs/modding/lua-api-reference.md`, `docs/modding/python-api-reference.md` |
| `npm run gen` | both | both |

`npm start` and `npm run build` run `npm run gen` first, so the reference is always in
sync with the code. `npm run build` additionally runs `npm run lint:docs`, which rejects
markdown that builds fine but renders wrong — most often an admonition written as
`:::note Title` instead of `:::note[Title]`.

To document something in the reference, write a `/** ... */` doc comment on the Haxe type
or field, or a `//` comment directly above a `registerFunction(...)` call, and regenerate.

## Layout

```text
docs/
├── intro.md
├── getting-started/   requirements, building, running, project.hxp, troubleshooting
├── architecture/      overview, source tree, boot, state flow, paths, timing, patches
├── subsystems/        gameplay, charts, characters, shaders, options, editors, audio, mobile…
├── modding/           folder layout, Lua, Python, HScript, hooks, events/notetypes
├── contributing/      workflow, code style, CI, docs
└── reference/         GENERATED
scripts/
├── haxe-parser.mjs          dependency-free Haxe parser
├── generate-api-docs.mjs    code reference generator
├── generate-script-api.mjs  Lua/Python API generator
└── check-doc-syntax.mjs     markdown/admonition lint
```

`sidebars.js` autogenerates one sidebar from the folder tree; ordering comes from
`sidebar_position` front matter and `_category_.json` files.

More detail: [Contributing → Documentation](./docs/contributing/documentation.md).
