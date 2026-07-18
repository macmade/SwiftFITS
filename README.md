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

This library provides a simple interface to read and write FITS files in Swift, based on the [FITS 4.0 standard](https://fits.gsfc.nasa.gov/fits_standard.html).

### Status

SwiftFITS supports both **reading and writing**. It parses existing FITS files into their header/data
structure and serializes them back to standards-compliant bytes. A compliant file round-trips
byte-for-byte; you can also build new files from scratch, and edit parsed files in place — only the
sections you modify are re-rendered, while every untouched section keeps its original bytes.

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
- **`END`** is excluded from a section's `properties` but is retained in the raw bytes, so a compliant
  file round-trips byte-for-byte through `FITSFile.data`.
- **Strict vs. lenient**: `.strict` rejects technically-noncompliant input, while `.lenient` (the
  default) tolerates common real-world deviations (unknown value types, trailing characters after a
  string's closing quote, non-printable header text, data-length mismatches, a missing space after
  the `=` value indicator, lowercase `e`/`d` float exponents, NUL-padded headers, a truncated
  trailing partial block, non-blank records after the `END` marker, NUL padding in value/comment
  fields, and orphaned `CONTINUE` records).
- **Serialization is symmetric**: `FITSSerializationOptions` mirrors the parsing options, with
  `.strict` and `.lenient` presets. On write, mandatory keywords, `BITPIX`/`NAXIS` geometry and each
  data segment's size are validated — `.strict` rejects any mismatch, while `.lenient` tolerates a
  data-size mismatch and coerces keyword case. The library manages the `END` marker and 2880-byte
  padding; the caller owns the mandatory keywords and their order.
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

#### Reading

```swift
import Foundation
import SwiftFITS

do
{
    let file = try FITSFile( url: URL( fileURLWithPath: "/path/to/file.fits" ), options: .lenient )
    
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

#### Writing & serialization

Build a file from scratch — a primary image HDU plus an optional extension — and write it out. The
mandatory keywords (`SIMPLE`/`XTENSION`, `BITPIX`, `NAXIS`, `NAXISn`, …) are populated for you:

```swift
import Foundation
import SwiftFITS

// A 3x2 8-bit image: six bytes of pixel data.
let file = try FITSFile( bitpix: 8, axes: [ 3, 2 ], data: Data( [ 1, 2, 3, 4, 5, 6 ] ) )

// Append a 4x4 16-bit image extension (4 * 4 * 2 = 32 bytes of data).
try file.appendExtension( type: "IMAGE", bitpix: 16, axes: [ 4, 4 ], data: Data( count: 32 ) )

try file.write( to: URL( fileURLWithPath: "/path/to/out.fits" ), options: .strict )
```

Edit a parsed file and write it back. Only the sections you touch are re-rendered; everything else is
preserved byte-for-byte:

```swift
let file = try FITSFile( url: URL( fileURLWithPath: "/path/to/file.fits" ), options: .lenient )

// Set or replace a keyword on the primary header.
try file.header?.setProperty( FITSProperty( name: "OBJECT", string: "M42", options: .strict ) )

// Reshape the primary data (512x512 16-bit = 512 * 512 * 2 bytes), keeping its
// geometry keywords in sync.
let pixels = Data( count: 512 * 512 * 2 )

try file.setPrimaryData( bitpix: 16, axes: [ 512, 512 ], data: pixels )

// Serialize to bytes, or write straight to disk.
let bytes = try file.serializedData( options: .lenient )

try file.write( to: URL( fileURLWithPath: "/path/to/edited.fits" ), options: .lenient )
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
