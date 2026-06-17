/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the Software), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Foundation

/// FITS-specific character sets used throughout parsing.
public extension CharacterSet
{
    /// The padding character used in FITS records.
    ///
    /// FITS fixes every record at 80 bytes and pads unused space with the
    /// ASCII space character (`0x20`). This set is used to trim that padding
    /// from keyword names, values and comments.
    static let fitsPadding = CharacterSet( charactersIn: "\u{20}" )

    /// The padding set extended with the NUL byte (`0x00`).
    ///
    /// Used when ``FITSParsingOptions/allowNulPadding`` is set to trim
    /// NUL-padded or NUL-terminated keywords and `END` markers.
    static let fitsPaddingWithNul = CharacterSet( charactersIn: "\u{20}\u{00}" )

    /// The characters permitted in a FITS keyword name.
    ///
    /// Per the FITS standard a keyword name may contain only uppercase
    /// letters, digits, the underscore and the hyphen.
    static let fitsKeyword = CharacterSet( charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_-" )
}
