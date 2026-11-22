# EmbyLogoTool — TuneIn genre artwork builder

`Build-GenreArtwork.ps1` is an offline maintainer tool. It renders the original neon cards (1280×720 JPEG)
that the [Emby TuneIn plugin](https://github.com/oconnoradv/EmbyTuneIn) bundles for its music genre folders.
The plugin does not run, download or build this artwork. Copy the JPEGs this tool produces into the plugin's
`MediaBrowser.Plugins.TuneIn\Images\genres` folder and commit them there.

The cards are original artwork: neon line art, futuristic type and a spaced subtitle. They contain no
TuneIn logos or station images.

## Requirements

- Windows PowerShell 5.1 (`System.Drawing`).
- Windows 11 fonts: Bahnschrift, Segoe UI Variable, Segoe UI Black, Cascadia Mono and Impact. On other
  systems, GDI+ falls back to a different font and the cards look different.
- Internet access to `opml.radiotime.com`, which supplies the current genre list.

## Usage

Run from this repository's root:

```powershell
# All genres, into .\output\genres (default)
powershell -NoProfile -ExecutionPolicy Bypass -File Build-GenreArtwork.ps1

# All genres, straight into a plugin checkout
powershell -NoProfile -ExecutionPolicy Bypass -File Build-GenreArtwork.ps1 -Output C:\src\EmbyTuneIn\MediaBrowser.Plugins.TuneIn\Images\genres

# A preview of selected genres in a scratch folder. -Only matches a guide ID or a -like name pattern.
powershell -NoProfile -ExecutionPolicy Bypass -File Build-GenreArtwork.ps1 -Output $env:TEMP\genres -Only 'c57944','Christmas*','Trance'
```

Each card prints `id  name  [style/motif]`. A full run takes about 20 seconds and writes about 123 files
(about 8.4 MB at JPEG quality 80).

## How it works

1. **Genre list.** The tool reads `Browse.ashx?c=music` for top-level genres (IDs `c…`/`g…`) and
   `Browse.ashx?id=<id>` for each genre's subgenres (`g…`). Each output file is named `<guide_id>.jpg`.
2. **Style.** `$Parents` maps every top-level genre to a style group and default motif. Subgenres inherit
   their parent's style.
3. **Typography and palette.** `$Styles` defines each style group's font, case, shear, title mode
   (`Fill` or `Tube` outline), maximum size and palette (`bgTop`, `bgBottom`, three neon colours).
   A subgenre uses the parent's colours, rotated by a per-genre seed, so siblings differ.
4. **Motif.** The `$Overrides` table maps subgenre name regexes to a motif and is checked in order; the
   first match wins. `$Places` gives a latitude and longitude, which mark World subgenres on the globe motif.
5. **Rendering.** `New-Card` draws, in order:
   - the gradient background, a soft radial glow and the HUD corners;
   - the motif, through `Neon`;
   - the title, auto-fitted on 1–3 lines by `Title-Path`;
   - the `// PARENT` subtitle.

## Customizing

- **New motif:** add `function Motif-<name>($cl, $info)` that calls `Neon $cl[i] { param($g, $c, $k) ... }`.
  - Draw around (0,0), within about ±240 × ±290; `$script:OX`/`$script:OY` place the artwork.
  - Build pens with `Pn $c <width> $k` so they get the glow and core scaling.
  - Then reference the motif from `$Parents` or `$Overrides`.
- **Glow strength:** `$script:Weight` scales every stroke (default 0.7). `$__cm.Matrix33` sets the glow
  opacity (default 0.65). The `0.08, 0.04, 0.02` scales set the glow radius. Higher values look louder
  and blurrier.
- **Title look:** edit the matching `$Styles` entry. `Tube` titles are outlined; `Fill` titles are solid.
- **New TuneIn genres** are picked up automatically and use their parent's defaults. Add an override
  when a more specific motif fits.

After you copy regenerated cards into the plugin, bump `GenreRevision` in `TuneInCategoryArtwork.cs`, so that Emby replaces the cached
folder images.
