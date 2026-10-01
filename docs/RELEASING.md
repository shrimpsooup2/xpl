# Releasing a build

How to put out a new version of xtrapartial: numbering it, building it, publishing it, and keeping the website in step. Do this for every full release.

## The version number

It lives in **one place**: `application/config/version` in [`project.godot`](../project.godot) (in the editor: *Project → Project Settings → Application → Config → Version*). Everything else reads it:

- the title screen's version tag (`src/ui/main_menu.gd`, `version_text()`);
- the website: `tools/build_site.sh` stamps it into the page (the tag under the logo and every download's tooltip), and the website workflow redeploys whenever `project.godot` changes.

So never type the version anywhere else (not in `site/index.html`, whose copy the build overwrites).

Numbering is `major.minor.patch`, and `0.x` while the game is in development:

| Release | Bump | Example |
|---|---|---|
| A full release (new maps, weapons, features) | minor, patch back to 0 | 0.1.0 → 0.2.0 |
| A fix to the last release, nothing new | patch | 0.2.0 → 0.2.1 |
| 1.0, and later big milestones | major | 0.9.0 → 1.0.0 |

**The network protocol is separate.** If a release changes anything that goes over the network (a message's shape, what the roster or the rules carry), bump `NetCodec.PROTOCOL` in `src/net/net_codec.gd` too: builds with different protocols refuse each other at the handshake (and *find a game* greys the other one's servers out). Say so in the release notes, since dedicated servers have to update with everyone else.

## Every full release

1. **Green first.** On `main`, run everything, the online tests included:
   ```
   tools/run_tests.sh
   ```
2. **Bump the version** in `project.godot` (above), and check the title screen shows it. Commit it on its own: `Release 0.2.0`.
3. **Export the builds** (*Project → Export*). Keep the file names the same every release, with no version in them, so the website's links never have to change:

   | File | What's in it |
   |---|---|
   | `xtrapartial-pc.zip` | The Windows `.exe` and the Linux x86_64 binary (64-bit), each with its `.pck` (or with the pack embedded) |
   | `xtrapartial-mac.zip` | The macOS `.app` (universal: Apple silicon and Intel) |
   | `xtrapartial-server.zip` | The Linux dedicated server: the Linux preset with the `dedicated_server` feature, exported as *dedicated server* (headless, no textures or sounds it doesn't need). It starts serving by itself (`DedicatedServer.requested()`); see [NETWORKING.md](NETWORKING.md#running-a-server) |

   The first time, set up the four export presets (Windows Desktop, Linux, macOS, and a second Linux one for the server) and commit `export_presets.cfg` (leave signing passwords and keys out of it).
4. **Publish it on GitHub**: *Releases → Draft a new release*, a new tag `v0.2.0` on the release commit, titled `xtrapartial 0.2.0`. In the notes, what's new since the last release (the GDD's revision history rows since then are a good list) and anything players or server hosts must know (a new protocol, settings reset). Attach the three zips, then publish.
5. **The website's downloads.** The download links in [`site/index.html`](../site/index.html) point at the latest release's files, so they only need setting once (the first release), and every release after that is picked up by itself:
   ```
   https://github.com/shrimpsooup2/xpl/releases/latest/download/xtrapartial-pc.zip
   https://github.com/shrimpsooup2/xpl/releases/latest/download/xtrapartial-mac.zip
   https://github.com/shrimpsooup2/xpl/releases/latest/download/xtrapartial-server.zip
   ```
   An empty link says *soon :)* on the site. If what a build needs changes (a newer macOS, another platform), change its tooltip too: the link's `title`.
6. **Check the site** once the *website* workflow has run (Actions tab): the tag under the logo and the tooltips show the new version, and each download starts.
7. **Tell the dedicated server operators** if the protocol changed, so they update their servers.

## A fix release

The same, with the patch number bumped (0.2.0 → 0.2.1) and only the builds that changed re-exported (attach all three to the release anyway, since the links point at the latest release).

## The website's pictures

When maps are dressed or the game looks different, retake the pictures (`site/shots/`, listed in the pictures card's `data-shots` in `site/index.html`): 1280 × 720 JPEGs, the game drawn at its 720p *pixels* setting, a few players posed in each.
