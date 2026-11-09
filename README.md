# Password Generator

A standalone, offline macOS desktop app that generates passwords. It is a generator only, not a password manager. It runs as a native window (no browser) and is sandboxed with no network entitlements, so macOS blocks all network access.

## Build and launch

Requires macOS 13+ and the Swift toolchain (Xcode or Command Line Tools).

```sh
./build_app.sh
open "build/Password Generator.app"
```

The app is ad-hoc signed. If you copy it to another Mac, the first launch may need right-click → Open.

## Using it

The password is shown at the top, with digits in blue and special characters in orange so it's easy
to read by eye. Below it, a strength meter rates it (Weak, Fair, Strong, Very strong) from its bits of
entropy: length × log2 of the number of possible characters.

| Control | What it does |
|---|---|
| **Copy** (⇧⌘C) | Copies to the clipboard. The clipboard is cleared after 30 seconds, unless you have copied something else since. |
| **New** (Return) | Makes a new password. Changing any setting also regenerates. |
| **Mark as used** (the seal button) | Tells the app you used this password. It is never suggested again, and a new one is shown. |
| **Length** | 8–256 characters, default 32. Use the slider, text box or stepper. |
| **Characters** | Switch lowercase, uppercase, digits and special characters on or off. "At least" sets the minimum count of that type. |
| **Special characters** | Editable set, shown while Special is on. Whitespace and duplicates are ignored. |
| **Avoid look-alikes** | Removes `I l 1 O 0 \|` from the pool. |
| **Repeat control** | Under the expandable section at the bottom. See below. |
| **Clear history…** | Forgets all used passwords, after confirmation. |

Your settings are kept between launches.

Every setting above is kept between launches: length, character types and their minimum counts, the special characters, look-alikes and repeat control. They are saved whenever they change, in the app's own sandboxed preferences (`~/Library/Containers/local.passwordgenerator/Data/Library/Preferences/`), and nothing leaves the Mac. To go back to the defaults, quit the app and run `defaults delete local.passwordgenerator settings`.

### Repeat control

The password is built in cycles. Each cycle is a random selection of distinct characters, so no character repeats until the cycle is used up.

- **Default (use every character once before any repeats):** a cycle is the whole pool, 94 characters with everything enabled. A password shorter than the pool never repeats a character. A longer one is built from full passes through the pool.
- **Distinct characters before a repeat:** turn the default off to set a smaller cycle, for example 10.
- A character is never repeated back-to-back across a cycle boundary.

This rule narrows the possible passwords slightly compared with fully random characters. At 32+ characters the result is still very strong.

### Used passwords

"Mark as used" stores a salted SHA-256 hash of the password, never the password itself, in `used_hashes.json`. The file is in the app's Application Support folder inside its sandbox container. It is mode `0600`, and the salt is random per install.

- The generator discards any password whose hash is in the history and tries again, up to 100 times.
- Copy does not mark a password as used. Only **Mark as used** does.
- With very small pools, such as digits only at length 8, a short or narrow password could be recovered from the hash file by brute force. Don't rely on the hash to protect those.
- With very small pools, enough used passwords can leave no unused ones. The app then shows an error.

## Layout

```
Package.swift
build_app.sh                 builds build/Password Generator.app
entitlements.plist           sandbox on, no network entitlements
Sources/PasswordCore/        generator and used-password store (no UI)
Sources/PasswordGenerator/   SwiftUI app
Tests/PasswordCoreTests/     unit tests
```

## Tests

```sh
swift test
```

They cover the length limits, the no-repeat cycles, the per-type minimums, the look-alike exclusion, and used-password persistence and filtering.
