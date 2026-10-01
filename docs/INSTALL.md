# Installation

Isaac Debug Console is distributed as one portable ARM64 dylib with three loading formats. Back
up Isaac's application data before changing an installation or using commands that modify a run.

## Rootless jailbreak

The rootless package installs:

```text
/var/jb/Library/MobileSubstrate/DynamicLibraries/IsaacDebugConsole.dylib
/var/jb/Library/MobileSubstrate/DynamicLibraries/IsaacDebugConsole.plist
```

Install `IsaacDebugConsole-rootless.deb` through a package manager or with `dpkg -i`, then fully
restart Isaac. ElleKit loads the dylib only into `com.Nicalis.Isaac-iOS`; the dylib itself does not
link against ElleKit, Substrate, or libhooker.

## LiveContainer private app

1. Extract `IsaacDebugConsole-LiveContainer.framework.zip`.
2. In LiveContainer, open **Tweaks** and create an app-specific folder.
3. Open that folder, choose **Import Tweak**, and select `IsaacDebugConsole.framework`.
4. Long-press Isaac, choose **Settings**, and assign the folder under **Tweak Folder**.
5. Keep **Don't Inject TweakLoader** and **Don't Load TweakLoader** disabled.
6. If LiveContainer reports a signature issue, use **Force Sign** on the imported framework.

Isaac must run as a private app. A global tweak folder is not recommended because the native
bridge is intentionally limited to one exact Isaac executable UUID.

## Embedded app bundle

The embedded archive contains the standalone dylib and this documentation. For a user-supplied
decrypted app bundle:

1. Create `Payload/Isaac.app/Frameworks` if it is absent.
2. Copy `IsaacDebugConsole.dylib` into that directory.
3. Add an `LC_LOAD_DYLIB` command to Isaac's executable for:

   ```text
   @executable_path/Frameworks/IsaacDebugConsole.dylib
   ```

4. Sign nested frameworks and dylibs first, then sign the main app bundle.
5. Package the `Payload` directory as an IPA and install it with the user's chosen signing method.

The project does not provide or download Isaac. It does not modify StoreKit, receipts, DLC
ownership, or purchase checks.

## Signing notes

- The dylib is ordinary ARM64 code and does not use JIT or unsigned executable memory.
- Network access and extra entitlements are not required.
- Re-signing may change the bundle identifier, application container, Keychain access groups, and
  App Store receipt behavior depending on the signing service.
- Changing the application identifier can create a new empty data container. Preserve a backup
  before replacing an existing installation.
- All embedded code must be signed by a certificate accepted for the final application bundle.

## Verification

After launch, pause an active run. The **Console** button should appear in the lower-left corner.
Run `status` first. A compatible build reports `Bridge: supported` and the expected executable
UUID. Native mutation remains disabled on an unknown executable.
