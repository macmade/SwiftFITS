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

/// Byte-level helpers used to inspect and split FITS data.
public extension Data
{
    /// A Boolean value indicating whether every byte is a 7-bit ASCII value.
    ///
    /// `true` when all bytes are in the range `0x00...0x7F`. FITS headers and
    /// extensions are required to be ASCII, so this is used to distinguish
    /// header/extension blocks from binary data blocks.
    var containsOnlyASCII: Bool
    {
        self.allSatisfy { $0 <= 0x7F }
    }

    /// A Boolean value indicating whether every byte is a printable FITS character.
    ///
    /// `true` when all bytes are in the range `0x20...0x7E`, the set of
    /// printable characters the FITS standard allows in header text.
    var containsOnlyFITSPrintable: Bool
    {
        self.allSatisfy { $0 >= 0x20 && $0 <= 0x7E }
    }

    /// Splits the data into consecutive chunks of a fixed size.
    ///
    /// - Parameter size: The size, in bytes, of each chunk. Must be positive.
    /// - Returns: The data split into contiguous slices of `size` bytes each.
    /// - Throws: ``FITSError/dataError(reason:)`` if `size` is not positive, or
    ///           if the data length is not an exact multiple of `size`.
    func chunked( by size: Int ) throws -> [ Data ]
    {
        if size <= 0
        {
            throw FITSError.dataError( reason: "Invalid chunk size" )
        }

        if self.count % size != 0
        {
            throw FITSError.dataError( reason: "Data cannot be chunked evenly" )
        }

        return stride( from: self.startIndex, to: self.endIndex, by: size ).map
        {
            self[ $0 ..< $0 + size ]
        }
    }
}
