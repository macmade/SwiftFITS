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
        case logical
        case integer
        case float
        case string
        case undefined
        case empty
        
        public var description: String
        {
            switch self
            {
                case .logical:       return "Logical"
                case .integer:       return "Integer"
                case .float:         return "Float"
                case .string:        return "String"
                case .undefined:     return "Undefined"
                case .empty:         return "Empty"
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
                let ( string, comment ) = try self.parseStringValueAndComment( data: data )
                
                return ( string, comment, .string )
            }
            else if let index = data.firstIndex( of: "/" )
            {
                let property        = data[ data.startIndex ..< index ].trimmingCharacters( in: .fitsPadding )
                let comment         = data[ data.index( after: index )... ].trimmingCharacters( in: .fitsPadding )
                let ( value, kind ) = try self.parseNonStringValue( data: property )
                
                return ( value, comment, kind )
            }
            else
            {
                let property        = data.trimmingCharacters( in: .fitsPadding )
                let ( value, kind ) = try self.parseNonStringValue( data: property )
                
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
    
    private class func parseStringValueAndComment( data: String ) throws -> ( value: String?, comment: String? )
    {
        guard let first = data.first, first == "'"
        else
        {
            throw FITSError.invalidPropertyData( reason: "Invalid property data" )
        }
        
        var index = data.index( after: data.startIndex )
        
        while index < data.endIndex
        {
            if data[ index ] == "'"
            {
                let next = data.index( after: index )
                
                if next < data.endIndex && data[ next ] == "'"
                {
                    index = data.index( after: next )
                }
                else
                {
                    break
                }
            }
            else
            {
                index = data.index( after: index )
            }
        }
        
        if index == data.endIndex
        {
            throw FITSError.invalidPropertyData( reason: "Invalid property data" )
        }
        
        let value  = String( data[ data.index( after: data.startIndex ) ..< index ] )
        let rest   = data[ index... ]
        
        let string: String? = if value.isEmpty
        {
            nil
        }
        else if value.unicodeScalars.allSatisfy( { $0 == " " } )
        {
            ""
        }
        else
        {
            value
        }
        
        if let index = rest.firstIndex( of: "/" )
        {
            let comment = rest[ rest.index( after: index )... ].trimmingCharacters( in: .fitsPadding )
            
            return ( string, comment )
        }

        return ( string, nil )
    }
    
    private class func parseNonStringValue( data: String ) throws -> ( value: Any?, kind: Kind )
    {
        let data = data.trimmingCharacters( in: .fitsPadding )
        
        guard data.isEmpty == false
        else
        {
            return ( nil, .undefined )
        }
        
        if let value = self.asLogical( data: data )
        {
            return ( value, .logical )
        }
        
        if let value = try self.asInteger( data: data )
        {
            return ( value, .integer )
        }
        
        if let value = try self.asFloatingPoint( data: data )
        {
            return ( value, .float )
        }
        
        return ( data, .empty )
    }
    
    private class func asLogical( data: String ) -> String?
    {
        let data = data.trimmingCharacters( in: .fitsPadding )
        
        if data == "T" || data == "F"
        {
            return data
        }
        
        return nil
    }
    
    private class func asInteger( data: String ) throws -> Int64?
    {
        let data  = data.trimmingCharacters(in: .fitsPadding)
        let regex = try NSRegularExpression( pattern: #"^[+-]?\d+$"#, options: [] )
        let range = NSRange( location: 0, length: data.utf16.count )

        if let _ = regex.firstMatch( in: data, options: [], range: range )
        {
            return Int64( data )
        }
        
        return nil
    }
    
    private class func asFloatingPoint( data: String ) throws -> Double?
    {
        let data  = data.trimmingCharacters(in: .fitsPadding)
        let regex = try NSRegularExpression( pattern: #"^[+-]?(?:\d+\.?\d*|\.\d+)([ED][+-]?\d+)?$"#, options: [] )
        let range = NSRange( location: 0, length: data.utf16.count )

        if let _ = regex.firstMatch( in: data, options: [], range: range )
        {
            return Double( data.replacingOccurrences( of: "D", with: "E" ) )
        }
        
        return nil
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
