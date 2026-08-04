# Humayoun Tool — Session Context

## What this is
A Windows-only tool that diagnoses a laptop/desktop's real hardware condition (battery, storage, CPU/GPU, RAM) and combines it with a user-answered condition survey and market price data to output an honest, realistic resale price range. Distributed like Chris Titus Tech's WinUtil: one PowerShell command, no installer, source on GitHub, hosted on Vercel.

## Scope history (for context, don't re-litigate unless asked)
- **Original idea**: cross-platform (iOS/Android/Windows/macOS), native app per platform, deep sensor/hardware diagnostics + market pricing + condition survey, eventual marketplace.
- **Reality check given**: true hardware diagnostics are platform-specific by nature (e.g. iOS blocks battery cycle count/health to all third-party apps, no entitlement bypasses this). A single "checks everything" cross-platform codebase isn't feasible; native/near-native code is required per OS for deep access.
- **Pivot (current scope)**: Windows only, laptops + desktops. Single PowerShell + WPF script, self-elevating, run via `irm <url> | iex`, following the WinUtil distribution model. Cross-platform vision is parked, not abandoned — revisit once Windows version is proven.

## Architecture
```
Client (PowerShell + WPF GUI, self-elevating)
   -> Diagnostics module   (battery, storage, CPU/GPU/RAM, BIOS date)
   -> Condition module     (guided survey: screen, body, ports, keyboard, webcam, speakers)
   -> Pricing module       (base market price x diagnostic score x condition score -> range)
```
Landing/install page is a separate static site (GitHub + Vercel), independent of the script logic.

## Files created so far

| File | Purpose | Status |
|---|---|---|
| `HumayounTool_v1.ps1` | Core tool — WPF GUI, self-elevating, live diagnostics (Overview/Battery/Storage tabs functional), condition survey scoring, price estimate calc | ✅ Created. Price tab needs manual base-price entry (see Known gaps) |
| `index.html` | Bilingual (Bangla/English) landing + install page for GitHub/Vercel | Complete, needs repo URL + stable script link filled in |
| `i.ps1` | Stable install stub served at `/i` — self-elevates, downloads latest script from GitHub, runs it | ✅ Created. Update the raw GitHub URL inside once repo is live. |

**Naming convention in use**: incremental version suffix on the script (`HumayounTool_v1.ps1` → `_v2` → `_v3`...). Landing page stays `index.html` (no versioning needed, git history covers it).

## Diagnostic capability notes (Windows-specific)
- Battery health/cycle count: read via `powercfg /batteryreport`, HTML output parsed with regex for DESIGN CAPACITY / FULL CHARGE CAPACITY / CYCLE COUNT. **Known fragility**: regex assumes English-locale report text; untested on non-English Windows installs.
- Storage health: `Get-PhysicalDisk` + `Get-StorageReliabilityCounter` (wear %, temperature, health status). Requires admin (script self-elevates).
- CPU/GPU/RAM/OS/BIOS date: standard `Get-CimInstance` (Win32_Processor, Win32_VideoController, Win32_PhysicalMemory, Win32_OperatingSystem, Win32_BIOS). BIOS ReleaseDate used as a manufacture-date proxy, not exact purchase date.

## Pricing logic (current, intentionally simple — MVP)
```
diagScore    = average(batteryHealthPercent, storageHealthScore)
overallScore = (diagScore * 0.5 + conditionScore * 0.5) / 100
priceMin     = basePrice * overallScore * 0.85
priceMax     = basePrice * overallScore * 1.05
```
`basePrice` is currently **manual entry** in the GUI — no live market data source wired in yet. This is the single biggest gap before the tool's core promise ("real market data, not guessing") is actually true end to end.

## Distribution plan
- Repo on GitHub, public, so the self-elevating script is auditable (this matters for trust — asking people to blind-pipe a script into `iex` only works if the source is inspectable).
- **Decided against**: reusing `humayounkobir.vercel.app` (ties the tool to an unrelated personal/portfolio site) and against URL shorteners (bit.ly-style links hide the real destination when piped into `iex`, can be hijacked/reassigned, and undercut the "verify it yourself" trust pitch on the landing page).
- **Decided instead**: a dedicated short domain just for this tool, decoupled from any personal site. Two options, not yet chosen between:
  - **Free**: new separate Vercel project named `hktool` (or similar available name) → `hktool.vercel.app`, no cost.
  - **Paid (~$10–15/yr)**: real short domain like `hktool.app` or `hktool.dev` pointed at the same Vercel project — matches how Chris Titus does it (`christitus.com/win`).
- Also shortening the script path itself from `/tool.ps1` to something terse like `/i` or `/get` (easier to type/read aloud).
- Vercel serves the static files. Two files needed at the project root/`public/` folder:
  - `index.html` (landing page, done — install command inside it needs updating once the domain is chosen)
  - the script itself at a short stable path (e.g. `/i`), always the latest version, so the command never changes even as the script is versioned internally as `_v1`, `_v2`, etc.
- Install command placeholder pending domain choice: `irm hktool.vercel.app/i | iex` (free) or `irm hktool.app/i | iex` (paid)

## Landing page design decisions
- **Bilingual by design, not translation-bolt-on**: every text element carries both `data-en` and `data-bn` attributes; a JS toggle swaps them live, no page reload. Numerals (score, %, price) convert to Bangla digits (০-৯) via a small mapping function when in Bangla mode.
- **Typography**: Baloo Da 2 (Bangla) + Baloo 2 (English) for display/headlines — same rounded type family across both scripts so the brand feels unified, not translated. Hind Siliguri + Nunito Sans for body text (readable at small sizes, same rounded terminals).
- **Color system**: emerald green (`#1C7A54`) = verified/healthy, warm amber (`#C97A2E`) = price/value, deep green-black ink instead of pure black. Deliberately avoided the generic AI-design defaults (cream+terracotta, near-black+neon, broadsheet/serif).
- **On the "100% accuracy" request**: intentionally not put on the page as a literal claim — it would read as spam and undermine trust. Instead the page proves credibility structurally: the hero mockup shows the actual tool output, the trust section explains the transparent formula, and links to open-source code on GitHub. This was a deliberate substitution, flagged to the user at the time.
- **Signature element**: hero scorecard mockup is a live rendering of what the tool actually outputs (score ring, battery/storage bars, price range), animated in on page load — the hero *is* the product demo.

## Known gaps / next steps (unordered, pick up whichever is next)
- [ ] Choose free (`hktool.vercel.app`) vs paid (`hktool.app`/`hktool.dev`) domain, set it up, then update the install command in `index.html` and the script's stable path (`/i`).
- [ ] Wire a real base-price source into the Price tab (manual entry today). Options discussed: manual research seed data (fastest), small backend API returning model → base price, or live market comp scraping (eBay/Swappa/local marketplace listings) as the eventual real "Price Engine."
- [x] Copy `HumayounTool_v1.ps1` into the repo — done, file created.
- [x] Create stable install stub `i.ps1` at repo root (Vercel will serve it at `/i`). Update raw GitHub URL inside once repo is created.
- [ ] Replace placeholder `https://github.com/` links in `index.html` with the real repo URL once created.
- [ ] Test battery report parsing on a non-English Windows locale.
- [ ] Export-to-JSON button for scan results (mentioned as a natural next feature, not yet built).
- [ ] Longer-term, parked: revisit cross-platform (macOS/iOS/Android) once Windows version is validated. iOS diagnostics will need a fundamentally different approach (no programmatic battery health access) — condition input will lean more on manual entry (e.g. user reads/photographs the Settings > Battery > Battery Health screen).

## Working style notes for this project
- Deliver actual files (create_file), not just code in chat.
- Incremental version naming for the script.
- Minimal comments in code.
