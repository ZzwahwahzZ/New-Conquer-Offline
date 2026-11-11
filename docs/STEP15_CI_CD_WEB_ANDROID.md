# Step 15 — Cloud CI/CD, Web and Android exports

## Scope
This change adds a Godot 4.3-stable GitHub Actions pipeline for the existing project. It does not reorder Autoloads or change the committed Mobile renderer.

## Pipeline
- Runs on every push to `main` and on `workflow_dispatch`.
- Imports project resources with the Godot 4.3 headless editor.
- Runs the Step 11, 12, 13 and 14 smoke tests in sequence.
- Exports WebGL 2 with the Godot Compatibility renderer and single-threaded Web export (`variant/thread_support=false`). The Web job changes the renderer in its ephemeral runner checkout only; the repository and Android export remain on Mobile.
- Publishes the web export through GitHub Pages.
- Builds a signed debug APK using Java 17, Android SDK 34 and a temporary debug keystore, then uploads `NewConquerOffline.apk` as a workflow artifact.

## Pages configuration
The repository Pages source has been confirmed by the project owner as **GitHub Actions**. The workflow runs `actions/configure-pages@v5` with `enablement: true` and then deploys using `actions/deploy-pages@v4`. If GitHub rejects first-time enablement because the workflow token lacks administrative Pages permissions, a repository administrator must provide a `PAGES_TOKEN` secret with Pages write and Administration read/write access. No token value is stored in this repository.

## Save and platform behavior
- Save v6 remains the project's existing binary save envelope. Godot's `user://` storage maps to browser-persistent storage (IndexedDB-backed virtual filesystem) for web exports and app-private storage on Android.
- Browser persistence depends on the browser allowing site storage/IndexedDB; private mode or storage eviction can affect persistence.
- Android saves remain in the app sandbox. Broad legacy external-storage permissions are intentionally disabled: `user://` does not require them and should not request unnecessary storage access.
- Android export is Landscape and ARM64. The debug keystore is generated only in the runner and is not committed.

## Renderer and Autoload invariants
The committed project stays on Godot 4.3 Mobile renderer for Android. WebGL2 requires Compatibility; therefore the web job changes the renderer only in its disposable runner workspace before web import/export. The committed Autoload order remains:
1. ClassSystem
2. GearDatabase
3. GearSystem
4. GlobalEconomy
5. GameState

## Artifact and URLs
- Web output: GitHub Pages deployment artifact from `build/web`.
- Android output: workflow artifact `NewConquerOffline-Android-APK`, containing `NewConquerOffline.apk`.
- Expected Pages URL: https://zzwahwahzz.github.io/New-Conquer-Offline/

## Verification status
A push to `main` is used to trigger the cloud workflow. Godot parser/import, smoke tests, exports, Pages deployment and APK artifact are only considered successful after the corresponding GitHub Actions jobs complete successfully. The run must be inspected before reporting completion.
