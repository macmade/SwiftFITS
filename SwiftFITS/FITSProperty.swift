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

public class FITSProperty: CustomStringConvertible
{
    public let name:    String
    public let value:   Any?
    public let comment: String?
    
    public convenience init( data: Data ) throws
    {
        guard let string = String( data: data, encoding: .ascii )
        else
        {
            throw FITSError.invalidPropertyData( reason: "Invalid ASCII data" )
        }
        
        try self.init( string: string )
    }
    
    public init( string: String ) throws
    {
        guard string.count == 80
        else
        {
            throw FITSError.invalidPropertyData( reason: "Invalid property data length" )
        }
        
        let name = String( string.prefix( 8 ) ).rightTrimmingCharacters( in: .fitsPadding )
        let data = String( string.dropFirst( 8 ) ).rightTrimmingCharacters( in: .fitsPadding )
        
        if data.count >= 2, data[ data.startIndex ] == "=", data[ data.index( after: data.startIndex ) ] == " "
        {
            self.value   = String( data.dropFirst( 2 ) ).leftTrimmingCharacters( in: .fitsPadding )
            self.comment = nil
        }
        else
        {
            self.value   = nil
            let comment  = data.leftTrimmingCharacters( in: .fitsPadding )
            self.comment = comment.isEmpty ? nil : comment
        }
        
        self.name = name
    }
    
    public var description: String
    {
        let name    = self.name.padding( toLength: 8, withPad: " ", startingAt: 0 )
        let comment = self.comment ?? "<nil>"
        let value   = if let value = self.value
        {
            String( describing: value )
        }
        else
        {
            "<nil>"
        }
        
        return "FITSProperty { name: \( name ), value: \( value ), comment: \( comment ) }"
    }
}
