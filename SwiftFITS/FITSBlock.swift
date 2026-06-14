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

/// A single fixed-size FITS block.
///
/// A FITS file is a sequence of 2880-byte blocks (``FITSFile/blockSize``).
/// This type wraps one such block and exposes the structural facts (ASCII-ness,
/// extension marker, end marker) the parser needs to group blocks into sections.
///
/// The structural flags are computed and cached lazily on first access, so a
/// block whose role the header geometry already fixes (a data block) is never
/// scanned. Because that caching mutates on read, ``FITSBlock`` is not
/// thread-safe and not `Sendable`.
public class FITSBlock: CustomStringConvertible
{
    /// The raw 2880 bytes of the block.
    public let data: Data

    /// A Boolean value indicating whether the block contains only ASCII bytes.
    ///
    /// Computed lazily, so data blocks the parser never inspects are not scanned.
    public private( set ) lazy var containsOnlyASCII: Bool = self.data.containsOnlyASCII

    /// A Boolean value indicating whether the block begins a new extension.
    ///
    /// `true` when the block is ASCII and starts with the `XTENSION=` keyword.
    public private( set ) lazy var hasExtensionMarker: Bool = self.containsOnlyASCII && self.data.starts( with: "XTENSION=".utf8 )

    /// Creates a block from its raw bytes.
    ///
    /// - Parameter data: The block's bytes. Must be exactly
    ///   ``FITSFile/blockSize`` (2880) bytes long.
    /// - Throws: ``FITSError/invalidBlockSize(size:)`` if `data` is not exactly
    ///   2880 bytes.
    public init( data: Data ) throws
    {
        guard data.count == FITSFile.blockSize
        else
        {
            throw FITSError.invalidBlockSize( size: data.count )
        }

        self.data = data
    }

    /// A Boolean value indicating whether the block's last non-blank record is
    /// the `END` marker.
    ///
    /// Computed lazily by scanning the block's 80-byte records. Always `false`
    /// for non-ASCII (data) blocks. Used to detect where a header or extension
    /// section ends.
    public private( set ) lazy var hasEndMarker: Bool =
    {
        guard self.containsOnlyASCII, let lines = try? self.data.chunked( by: 80 )
        else
        {
            return false
        }

        return lines.compactMap
        {
            chunk -> String? in

            guard let line = String( data: chunk, encoding: .ascii ),
                  line.rightTrimmingCharacters( in: .fitsPadding ).isEmpty == false
            else
            {
                return nil
            }

            return line
        }
        .last?.hasPrefix( "END" ) ?? false
    }()

    /// A textual summary of the block's structural flags.
    public var description: String
    {
        "FITSBlock { containsOnlyASCII: \( self.containsOnlyASCII ), hasEndMarker: \( self.hasEndMarker ), hasExtensionMarker: \( self.hasExtensionMarker ) }"
    }
}
