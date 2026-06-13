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
