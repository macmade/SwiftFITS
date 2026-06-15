SwiftFITS
=========

[![Build Status](https://img.shields.io/github/actions/workflow/status/macmade/SwiftFITS/ci-mac.yaml?label=macOS&logo=apple)](https://github.com/macmade/SwiftFITS/actions/workflows/ci-mac.yaml)
[![Issues](http://img.shields.io/github/issues/macmade/SwiftFITS.svg?logo=github)](https://github.com/macmade/SwiftFITS/issues)
![Status](https://img.shields.io/badge/status-active-brightgreen.svg?logo=git)
![License](https://img.shields.io/badge/license-mit-brightgreen.svg?logo=open-source-initiative)  
[![Contact](https://img.shields.io/badge/follow-@macmade-blue.svg?logo=twitter&style=social)](https://twitter.com/macmade)
[![Sponsor](https://img.shields.io/badge/sponsor-macmade-pink.svg?logo=github-sponsors&style=social)](https://github.com/sponsors/macmade)

### About

FITS Image Library for Swift.

This library provides a simple interface to read FITS files in Swift, based on the [FITS 4.0 standard](https://fits.gsfc.nasa.gov/fits_standard.html).

### Status

SwiftFITS is currently **read-only**: it parses existing FITS files into their header/data structure.
Write and serialization support is planned but not yet implemented.

### Conformance & Limitations

SwiftFITS targets the base [FITS 4.0 standard](https://fits.gsfc.nasa.gov/fits_standard.html). The
following properties are intentional, not latent surprises:

- **Keyword names** may contain only `A`–`Z`, `0`–`9`, `_` and `-`, and must be left-justified in the
  8-byte keyword field (a leading space is rejected).
- **Long-keyword conventions** are out of scope: `HIERARCH` and similar ESO conventions are treated as
  ordinary 8-byte keywords, not expanded. Only `CONTINUE`/`HISTORY`/`COMMENT` multi-record merging is
  supported.
- **Mandatory keywords** (`SIMPLE`/`XTENSION`, `BITPIX`, `NAXIS`, `NAXISn`, and `PCOUNT`/`GCOUNT` for
  extensions) must appear in their exact standard order and index — this is enforced even in lenient
  mode.
- **Section layout is geometry-driven**: each header's declared geometry
  (`|BITPIX|/8 × GCOUNT × (PCOUNT + ∏ NAXISn)`, with random groups handled) determines exactly how many
  data blocks follow, rather than guessing from byte content. Trailing all-blank padding is preserved.
- **`END`** is excluded from a section's `properties` but is retained in the raw bytes, so a parsed file
  round-trips byte-for-byte through `FITSFile.data`.
- **Strict vs. lenient**: `.strict` rejects technically-noncompliant input, while `.lenient` (the
  default) tolerates common real-world deviations (unknown value types, trailing characters after a
  string's closing quote, non-printable header text, data-length mismatches, a missing space after
  the `=` value indicator, lowercase `e`/`d` float exponents, and NUL-padded headers).
- **Not thread-safe**: `FITSFile`, `FITSSection` and `FITSBlock` carry mutable state and cache structural
  facts lazily on read, so they are not `Sendable` and must not be shared across threads without external
  synchronization.

### Requirements & Portability

SwiftFITS is written in pure Swift and depends only on Foundation — no third-party dependencies.
It is developed, built and tested on macOS (see the CI badge above). Being Foundation-only, the
library is expected to be portable to Linux; Linux CI and SwiftPM-on-Linux verification are not yet
in place and are tracked as future work.

### Swift Package Manager

SwiftFITS ships a `Package.swift` and can be consumed as a Swift package. Add it to your
dependencies:

```swift
.package( url: "https://github.com/macmade/SwiftFITS.git", branch: "main" )
```

The Xcode project (`SwiftFITS.xcodeproj`) is also provided for development.

### Cloning

This project uses submodules.  
To clone it, use the following command:

```bash
git clone --recursive https://github.com/macmade/SwiftFITS.git
```

### Example Usage

```swift
import Foundation
import SwiftFITS

do
{
    let file = try FITSFile( url: URL( fileURLWithPath: "/path/to/file.fits" ) )
    
    if let header = file.header
    {
        print( header.properties )
    }
}
catch // SwiftFITS.FITSError
{
    print( error )
}
```

License
-------

Project is released under the terms of the MIT License.

Repository Infos
----------------

    Owner:          Jean-David Gadina - XS-Labs
    Web:            www.xs-labs.com
    Blog:           www.noxeos.com
    Twitter:        @macmade
    GitHub:         github.com/macmade
    LinkedIn:       ch.linkedin.com/in/macmade/
    StackOverflow:  stackoverflow.com/users/182676/macmade
