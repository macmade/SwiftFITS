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

public class FITSBlock: CustomStringConvertible
{
    public let data:               Data
    public let containsOnlyASCII:  Bool
    public let hasEndMarker:       Bool
    public let hasExtensionMarker: Bool

    public init( data: Data ) throws
    {
        self.data              = data
        self.containsOnlyASCII = data.containsOnlyASCII

        guard data.count == FITSFile.blockSize
        else
        {
            throw FITSError.invalidBlockSize( size: data.count )
        }

        if data.containsOnlyASCII
        {
            let lines = try data.chunked( by: 80 ).map
            {
                guard let line = String( data: $0, encoding: .ascii )
                else
                {
                    throw FITSError.invalidBlockData( reason: "Invalid ASCII data" )
                }

                return line
            }

            self.hasExtensionMarker = lines.first?.hasPrefix( "XTENSION=" ) ?? false
            let nonEmptyLines       = lines.compactMap { $0.rightTrimmingCharacters( in: .fitsPadding ).isEmpty ? nil : $0 }
            self.hasEndMarker       = nonEmptyLines.last?.hasPrefix( "END" ) ?? false
        }
        else
        {
            self.hasEndMarker       = false
            self.hasExtensionMarker = false
        }
    }

    public var description: String
    {
        "FITSBlock { containsOnlyASCII: \( self.containsOnlyASCII ), hasEndMarker: \( self.hasEndMarker ), hasExtensionMarker: \( self.hasExtensionMarker ) }"
    }
}
