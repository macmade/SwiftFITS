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
    public enum Kind: CustomStringConvertible
    {
        case string
        case empty
        
        public var description: String
        {
            switch self
            {
                case .string: return "String"
                case .empty:  return "Empty"
            }
        }
    }
    
    public let name:    String
    public let kind:    Kind
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
        
        let name                     = try FITSProperty.parseName(  string: String( string.prefix( 8 ) ) )
        let ( value, comment, kind ) = try FITSProperty.parseValueAndComment( string: String( string.dropFirst( 8 ) ) )
        self.name                    = name
        self.value                   = value
        self.comment                 = comment
        self.kind                    = kind
    }
    
    private class func parseName( string: String ) throws -> String
    {
        let name = string.rightTrimmingCharacters( in: .fitsPadding )
        
        if name.unicodeScalars.allSatisfy( { CharacterSet.fitsKeyword.contains( $0 ) } ) == false
        {
            throw FITSError.invalidPropertyData( reason: "Invalid property name" )
        }
        
        return name
    }
    
    private class func parseValueAndComment( string: String ) throws -> ( value: Any?, comment: String?, kind: Kind )
    {
        let string = string.rightTrimmingCharacters( in: .fitsPadding )
        
        if string.count >= 2, string[ string.startIndex ] == "=", string[ string.index( after: string.startIndex ) ] == " "
        {
            let data = String( string.dropFirst( 2 ) )
            
            guard let first = data.first
            else
            {
                throw FITSError.invalidPropertyData( reason: "Invalid property data" )
            }
            
            if first == "'"
            {
                let ( string, comment ) = try self.parseStringValueAndComment( string: data )
                
                return ( string, comment, .string )
            }
            else if let index = data.firstIndex( of: "/" )
            {
                let property        = data[ data.startIndex ..< index ].trimmingCharacters( in: .fitsPadding )
                let comment         = data[ data.index( after: index )... ].trimmingCharacters( in: .fitsPadding )
                let ( value, kind ) = try self.parseNonStringValue( string: property )
                
                return ( value, comment, kind )
            }
            else
            {
                let property        = data.trimmingCharacters( in: .fitsPadding )
                let ( value, kind ) = try self.parseNonStringValue( string: property )
                
                return ( value, nil, kind )
            }
        }
        else if let index = string.firstIndex( of: "/" )
        {
            let comment = string[ string.index( after: index )... ].trimmingCharacters( in: .fitsPadding )
            
            return ( nil, comment, .empty )
        }
         
        return ( nil, nil, .empty )
    }
    
    private class func parseStringValueAndComment( string: String ) throws -> ( value: String, comment: String? )
    {
        guard let first = string.first, first == "'"
        else
        {
            throw FITSError.invalidPropertyData( reason: "Invalid property data" )
        }
        
        var index = string.index( after: string.startIndex )
        
        while index < string.endIndex
        {
            if string[ index ] == "'"
            {
                let next = string.index( after: index )
                
                if next < string.endIndex && string[ next ] == "'"
                {
                    index = string.index( after: next )
                }
                else
                {
                    break
                }
            }
            else
            {
                index = string.index( after: index )
            }
        }
        
        if index == string.endIndex
        {
            throw FITSError.invalidPropertyData( reason: "Invalid property data" )
        }
        
        let value = String( string[ string.index( after: string.startIndex ) ..< index ] )
        let rest  = string[ index... ]
        
        if let index = rest.firstIndex( of: "/" )
        {
            let comment = rest[ rest.index( after: index )... ].trimmingCharacters( in: .fitsPadding )
            
            return ( value, comment )
        }

        return ( value, nil )
    }
    
    private class func parseNonStringValue( string: String ) throws -> ( value: Any, kind: Kind )
    {
        return ( string, .empty )
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
        
        return "FITSProperty { name: \( name ), kind: \( self.kind ), value: \( value ), comment: \( comment ) }"
    }
}
