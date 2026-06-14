/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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

/// One-sided trimming helpers used when parsing space-padded FITS records.
public extension String
{
    /// Returns a string with the characters in `characterSet` removed from the
    /// start. Symmetric counterpart of ``rightTrimmingCharacters(in:)``; kept
    /// as an intentional public helper. Returns an empty string when every
    /// character belongs to `characterSet`.
    func leftTrimmingCharacters( in characterSet: CharacterSet ) -> String
    {
        let scalars = self.unicodeScalars

        if let start = scalars.firstIndex( where: { characterSet.contains( $0 ) == false } )
        {
            return String( scalars[ start... ] )
        }
        else
        {
            return ""
        }
    }

    /// Returns a string with the characters in `characterSet` removed from the
    /// end. Symmetric counterpart of ``leftTrimmingCharacters(in:)``. Returns
    /// an empty string when every character belongs to `characterSet`.
    func rightTrimmingCharacters( in characterSet: CharacterSet ) -> String
    {
        let scalars = self.unicodeScalars

        if let end = scalars.lastIndex( where: { characterSet.contains( $0 ) == false } )
        {
            return String( scalars[ ...end ] )
        }
        else
        {
            return ""
        }
    }
}
