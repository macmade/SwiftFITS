/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2025 Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Foundation

public class FITSSection: CustomStringConvertible
{
    public enum Kind
    {
        case header
        case xtension
        case data
    }
    
    public  let kind:   Kind
    private var blocks: [ FITSBlock ] = []
    
    public init( kind: Kind, block: FITSBlock? ) throws
    {
        self.kind = kind
        
        if let block = block
        {
            try self.append( block: block )
        }
    }
    
    public var data: Data
    {
        self.blocks.reduce( Data() ) { $0 + $1.data }
    }
    
    public var canAppendData: Bool
    {
        self.kind == .data || self.blocks.last?.hasEndMarker ?? false == false
    }
    
    public func append( block: FITSBlock ) throws
    {
        if ( self.kind == .header || self.kind == .xtension ), block.containsOnlyASCII == false
        {
            throw FITSError( message: "Block contains non-ASCII characters" )
        }
        
        if ( self.kind == .header || self.kind == .xtension ), let last = self.blocks.last, last.hasEndMarker
        {
            throw FITSError( message: "Cannot append block after end marker" )
        }
        
        self.blocks.append( block )
    }
    
    public var description: String
    {
        "FITSSection { kind: \( self.kind ), chunks: \( self.blocks.count ), dataSize: \( self.data.count ) }"
    }
}
