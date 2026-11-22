# Tattoo Studio

An Android-first, offline-capable **Flutter tattoo design editor**. This is a
functional early prototype, not an AI tattoo generator.

## Features implemented

- Create, rename, reopen and delete local editable projects.
- Import **multiple images** as independent layers.
- **Smart Crop**: remove plain white background and excess blank borders.
- **Split Sheet**: detect widely separated designs on a flash sheet and add each
  as a layer. Works best with clean white or transparent backgrounds.
- **Import unchanged** for artwork that needs its original background.
- Drag, pinch-resize, rotate, flip, duplicate, hide, lock, reorder or delete
  layers. Undo and redo changes.
- Export a white-background PNG through the Android/iOS share sheet.
- Everything runs locally; no login, cloud database or AI API keys required.

## Start using the app on Android through GitHub

The archive contains Flutter source code. **It is not an installable APK.**
The GitHub Actions workflow builds the APK after the code is placed in a new
repository. Never upload this project to your existing Drift repositories.

1. Create a separate repository at https://github.com/new named `Tattoo-Studio`.
   Choose **Public** or **Private**; either can work with GitHub Actions subject
   to account limits. **Do not initialize with a README**, since this project
   already includes one.
2. Upload the starter source to the new repository (if not committed yet).
   Preserve its `.github` workflow directory.
3. Open your repository's **Actions** tab; enable workflows if prompted.
4. Choose **Build Android debug APK** and **Run workflow**. It also runs on a
   push to `main`.
5. After a successful run, open the workflow run and download the artifact
   `tattoo-studio-android-debug`. Extract the artifact ZIP to get `app-debug.apk`.
6. Install the APK on Android (allow installation from that download source if
   Android prompts). This is a debug build for testing, not a Play Store build.

If the workflow fails, copy its first error and use that to correct the code.
The project has not been compiled locally because the Flutter SDK is not
available in the authoring environment; the first CI build is the validation.

## Develop locally (computer with Flutter SDK)

```bash
flutter create . --platforms=android,ios --project-name=tattoo_studio
flutter pub get
flutter test
flutter run
```

To build an Android test APK locally:

```bash
flutter build apk --debug
```

## Project layout

- `lib/models` — editable design and layer JSON data models.
- `lib/services/smart_extract.dart` — offline background removal, crop,
  and connected-region detection.
- `lib/services/project_repository.dart` — local project and image files.
- `lib/screens/projects_screen.dart` — gallery and project creation.
- `lib/screens/editor_screen.dart` — canvas, transforms, layers, importing,
  undo/redo, sharing/export.
- `test/` — extraction and model round-trip tests.
- `.github/workflows/` — automated APK build.
- `docs/ROADMAP.md` — current functionality, limitations and next milestones.

## Known limitations

This prototype does not yet offer freehand lasso selection, erasing within a
layer, raster masks, brush drawing, image registration for body placement,
AI-generated artwork, or adaptive background segmentation. Split Sheet may not
separate touching or overlapping designs; complex edits remain manual work for
future versions. Current PNG export is 1800 × 2400 px at unspecified physical
print size; confirm scale and image quality before actual stencil printing.

Projects are stored in the app's local documents folder. Export PNGs outside
the app if you want backups before uninstalling or resetting the device.
