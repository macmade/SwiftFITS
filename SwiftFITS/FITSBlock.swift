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

        self.hasExtensionMarker = self.containsOnlyASCII && data.starts( with: "XTENSION=".utf8 )
    }

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

    public var description: String
    {
        "FITSBlock { containsOnlyASCII: \( self.containsOnlyASCII ), hasEndMarker: \( self.hasEndMarker ), hasExtensionMarker: \( self.hasExtensionMarker ) }"
    }
}
