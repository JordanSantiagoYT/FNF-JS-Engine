// @ts-check
// Docusaurus configuration for the Phoenix Engine documentation site.
// See https://docusaurus.io/docs/api/docusaurus-config

import {themes as prismThemes} from 'prism-react-renderer';

const organizationName = 'havaianasdestruido';
const projectName = 'FNF-Phoenix-Engine';

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Phoenix Engine',
  tagline: 'Codebase documentation for the FNF Phoenix Engine',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  url: `https://${organizationName}.github.io`,
  baseUrl: `/${projectName}/`,

  organizationName,
  projectName,
  trailingSlash: false,
  deploymentBranch: 'gh-pages',

  onBrokenLinks: 'throw',
  onBrokenAnchors: 'throw',

  markdown: {
    mermaid: true,
    // `.md` files are parsed as CommonMark, `.mdx` as MDX. The generated
    // reference pages contain Haxe generics (`Array<Foo>`) and other
    // characters MDX would try to read as JSX.
    //
    // Consequence: the MDX-v1 compat layer is off under `future.v4`, so
    // admonitions must use the directive-label syntax `:::note[Title]` —
    // `:::note Title` renders as plain text. `npm run lint:docs` enforces it.
    format: 'detect',
    hooks: {
      onBrokenMarkdownLinks: 'throw',
    },
  },
  themes: ['@docusaurus/theme-mermaid'],

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: './sidebars.js',
          routeBasePath: 'docs',
          editUrl: `https://github.com/${organizationName}/${projectName}/tree/main/website/`,
          showLastUpdateTime: true,
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/phoenix-icon.png',
      colorMode: {
        defaultMode: 'dark',
        respectPrefersColorScheme: true,
      },
      navbar: {
        title: 'Phoenix Engine',
        logo: {
          alt: 'Phoenix Engine',
          src: 'img/logo.png',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'docsSidebar',
            position: 'left',
            label: 'Documentation',
          },
          {
            to: '/docs/reference',
            position: 'left',
            label: 'Code reference',
          },
          {
            to: '/docs/modding/overview',
            position: 'left',
            label: 'Modding',
          },
          {
            href: `https://github.com/${organizationName}/${projectName}`,
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Docs',
            items: [
              {label: 'Introduction', to: '/docs/intro'},
              {label: 'Building', to: '/docs/getting-started/building'},
              {label: 'Architecture', to: '/docs/architecture/overview'},
              {label: 'Code reference', to: '/docs/reference'},
            ],
          },
          {
            title: 'Modding',
            items: [
              {label: 'Mod folder layout', to: '/docs/modding/mod-folder-structure'},
              {label: 'Lua scripting', to: '/docs/modding/lua-scripting'},
              {label: 'Python scripting', to: '/docs/modding/python-scripting'},
              {label: 'Script hooks', to: '/docs/modding/script-hooks'},
            ],
          },
          {
            title: 'Project',
            items: [
              {label: 'Repository', href: `https://github.com/${organizationName}/${projectName}`},
              {label: 'Issues', href: `https://github.com/${organizationName}/${projectName}/issues`},
              {label: 'Releases', href: `https://github.com/${organizationName}/${projectName}/releases`},
              {label: 'Upstream JS Engine', href: 'https://github.com/JordanSantiagoYT/FNF-JS-Engine'},
            ],
          },
        ],
        copyright: `Phoenix Engine docs · built with Docusaurus · Friday Night Funkin' is © its respective authors.`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
        additionalLanguages: ['haxe', 'lua', 'python', 'bash', 'json', 'ini', 'java', 'glsl'],
      },
      tableOfContents: {
        minHeadingLevel: 2,
        maxHeadingLevel: 4,
      },
    }),
};

export default config;
