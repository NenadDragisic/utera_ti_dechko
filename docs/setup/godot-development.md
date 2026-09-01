# Godot development and export setup

## Pinned toolchain

Use the standard, non-.NET Godot **4.7.2-stable** console executable:

```text
C:\Users\Nenad\Desktop\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe
```

Do not substitute the older 4.5 installation. The project and every preset use the Compatibility renderer. Android uses sensor orientation (`display/window/handheld/orientation=6`), which permits portrait, reverse portrait, landscape, and reverse landscape.

Install the official Godot 4.7.2 export templates through **Editor > Manage Export Templates**. The required template directory on this Windows machine is:

```text
C:\Users\Nenad\AppData\Roaming\Godot\export_templates\4.7.2.stable
```

The upstream `Godot_v4.7.2-stable_export_templates.tpz` used for the recorded release has SHA-512:

```text
ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079
```

## Android SDK and JDK

In **Editor Settings > Export > Android**, configure:

```text
Java SDK Path:    C:\Program Files\Android\Android Studio\jbr
Android SDK Path: C:\Users\Nenad\AppData\Local\Android\Sdk
```

The Android preset builds a universal debug APK for `arm64-v8a` and `x86_64`. Debug exports use Godot's locally generated debug keystore. Before a distributable release, set a private release keystore and alias outside the repository, increment `version/code`, review `version/name`, and create a release APK or AAB. Never commit keystores, passwords, `export_credentials.cfg`, or local SDK paths containing credentials.

## Import and automated tests

Run commands from the repository root. `tools/test.ps1` resolves the project through Windows before passing an absolute path to Godot; this avoids ambiguous WSL working-directory handling.

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tools/test.ps1
```

Run a clean editor import/parser/resource gate separately:

```powershell
$Godot = 'C:\Users\Nenad\Desktop\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$ProjectPath = (Resolve-Path '.').ProviderPath
& $Godot --headless --path $ProjectPath --editor --quit
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
```

Verify the checked-in word import independently:

```bash
python3 tools/validate_words.py data/baza_words.txt --expected-count 18064
```

Expected result:

```text
count=18064 invalid=0 duplicate=0 fingerprint=0152ee75650f9fd2568ca4ad6c4c93db5eb3d01758d0ec30fe158063847b7fed
```

To recreate the file from a deliberately saved copy of the audited reference page, run `python3 tools/extract_baza.py <reference.html> data/baza_words.txt`, then run the validation command above. Do not make release verification depend on the live reference site.

## Exports

`export_presets.cfg` defines the three production packs. All presets exclude `.git`, `.superpowers`, `tests`, `tools`, `docs`, and `addons/gut`. Generated output stays below ignored `builds/`.

```powershell
$Godot = 'C:\Users\Nenad\Desktop\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$ProjectPath = (Resolve-Path '.').ProviderPath

New-Item -ItemType Directory -Force -Path `
    (Join-Path $ProjectPath 'builds\windows'), `
    (Join-Path $ProjectPath 'builds\web'), `
    (Join-Path $ProjectPath 'builds\android') | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $ProjectPath 'builds\.gdignore') | Out-Null

& $Godot --headless --path $ProjectPath --export-release 'Windows Desktop' (Join-Path $ProjectPath 'builds\windows\utera-ti-dechko.exe')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $Godot --headless --path $ProjectPath --export-release 'Web' (Join-Path $ProjectPath 'builds\web\index.html')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $Godot --headless --path $ProjectPath --export-debug 'Android' (Join-Path $ProjectPath 'builds\android\utera-ti-dechko-debug.apk')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
```

The targets are:

- **Windows Desktop:** release, x86_64.
- **Web:** release, single-threaded (`variant/thread_support=false`), no GDExtensions. Godot's Web `user://` backend uses IndexedDB when the browser/origin permits persistence.
- **Android:** debug APK, `arm64-v8a` plus `x86_64`, app ID `com.prslafabrika.uteratidechko`, sensor orientation.

The root window uses a 1440×900 design size only when both logical dimensions can
hold it. Smaller Web windows use their native CSS-pixel size; Android converts
the physical display through its reported DPI before selecting a logical size.
In mobile Android gameplay only, landscape hides the nonessential brand/footer
chrome and outer vertical margins so a complete active cell row remains above
the expanded on-screen keyboard. Returning to portrait or Home restores the
full shell.

## Running the Web build

Do not open `index.html` with `file://`. WebAssembly loading and browser persistence require an HTTP origin. Keep the same origin and port when testing reload persistence:

```bash
python3 -m http.server 8060 --directory builds/web
```

Open <http://127.0.0.1:8060/>. Test a wide desktop viewport and mobile responsive viewports at 390×844 and 844×390. IndexedDB is origin-scoped, so changing the host or port creates a different save store. Private browsing, storage denial, or clearing site data can make persistence unavailable; the application must remain playable and show its durability warning.

## Save locations

The canonical file is always `user://save_v1.json` from application code.

| Platform | Physical storage |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\Utera ti dechko\save_v1.json` |
| Web | Browser IndexedDB for the exact HTTP origin; inspect it in DevTools under Application/Storage. There is no ordinary host file path. |
| Android | App-private storage, normally `/data/user/0/com.prslafabrika.uteratidechko/files/save_v1.json`; a debuggable install can inspect it with `adb shell run-as com.prslafabrika.uteratidechko ls files`. |

Do not copy real user saves into the repository. Corrupt-save checks should use an isolated profile, emulator, or test double.

## Release evidence

Follow [the release smoke checklist](../testing/release-smoke-checklist.md). Record automated checks, export construction, exported-runtime launches, browser/emulator interaction, and genuinely human/manual observations separately. A headless or scripted check is not manual evidence.
