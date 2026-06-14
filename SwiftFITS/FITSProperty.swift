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

public class FITSProperty: CustomStringConvertible
{
    public enum Kind: CustomStringConvertible
    {
        case logical
        case integer
        case float
        case string
        case undefined
        case unknown

        public var description: String
        {
            switch self
            {
                case .logical:       return "Logical"
                case .integer:       return "Integer"
                case .float:         return "Float"
                case .string:        return "String"
                case .undefined:     return "Undefined"
                case .unknown:       return "Unknown"
            }
        }
    }

    public enum Value: Equatable
    {
        case logical( Bool )
        case integer( Int64 )
        case float( Double )
        case string( String )
        case undefined
        case unknown( String )

        public var logical: Bool?
        {
            if case .logical( let value ) = self { value } else { nil }
        }

        public var integer: Int64?
        {
            if case .integer( let value ) = self { value } else { nil }
        }

        public var float: Double?
        {
            if case .float( let value ) = self { value } else { nil }
        }

        public var string: String?
        {
            if case .string( let value ) = self { value } else { nil }
        }
    }

    public private( set ) var name:    String
    public private( set ) var value:   Value
    public private( set ) var comment: String?

    public var kind: Kind
    {
        switch self.value
        {
            case .logical:   return .logical
            case .integer:   return .integer
            case .float:     return .float
            case .string:    return .string
            case .undefined: return .undefined
            case .unknown:   return .unknown
        }
    }

    public convenience init( data: Data, options: FITSParsingOptions = .lenient ) throws
    {
        guard let string = String( data: data, encoding: .ascii )
        else
        {
            throw FITSError.invalidPropertyData( reason: "Invalid ASCII data" )
        }

        try self.init( string: string, options: options )
    }

    public init( string: String, options: FITSParsingOptions = .lenient ) throws
    {
        guard string.count == 80
        else
        {
            throw FITSError.invalidPropertyData( reason: "Invalid property data length (\( string.count )" )
        }

        let name = try FITSProperty.parseName( string: String( string.prefix( 8 ) ) )

        if name == "HISTORY" || name == "COMMENT"
        {
            self.name    = name
            self.value   = .undefined
            self.comment = try FITSProperty.parseCommentOnly( string: String( string.dropFirst( 8 ) ) )
        }
        else if name.isEmpty
        {
            self.name    = name
            self.value   = .undefined
            self.comment = try FITSProperty.parseCommentOnly( string: String( string.dropFirst( 8 ) ) )
        }
        else
        {
            let ( value, comment ) = try FITSProperty.parseValueAndComment( name: name, string: String( string.dropFirst( 8 ) ), options: options )
            self.name              = name
            self.value             = value
            self.comment           = comment
        }
    }

    public func merge( with property: FITSProperty ) throws
    {
        if property.name == "HISTORY"
        {
            guard self.name == "HISTORY"
            else
            {
                throw FITSError.invalidPropertyData( reason: "Cannot merge a \( self.name ) property with a \( property.name ) property" )
            }

            self.comment = FITSProperty.mergedComment( self.comment, property.comment )
        }
        else if property.name == "COMMENT"
        {
            guard self.name == "COMMENT"
            else
            {
                throw FITSError.invalidPropertyData( reason: "Cannot merge a \( self.name ) property with a \( property.name ) property" )
            }

            self.comment = FITSProperty.mergedComment( self.comment, property.comment )
        }
        else if property.name == "CONTINUE"
        {
            guard case .string( let str1 ) = self.value, case .string( let str2 ) = property.value
            else
            {
                throw FITSError.invalidPropertyData( reason: "Cannot merge a \( self.name ) property with a \( property.name ) property - Invalid type" )
            }

            guard str1.last == "&"
            else
            {
                throw FITSError.invalidPropertyData( reason: "Cannot merge a \( self.name ) property with a \( property.name ) property - No continue flag" )
            }

            self.value   = .string( String( str1.dropLast( 1 ) + str2 ) )
            self.comment = FITSProperty.mergedComment( self.comment, property.comment )
        }
        else
        {
            throw FITSError.invalidPropertyData( reason: "Cannot merge a \( self.name ) property with a \( property.name ) property" )
        }
    }

    private class func mergedComment( _ lhs: String?, _ rhs: String? ) -> String?
    {
        // Join only the non-nil parts so a nil side never contributes a stray
        // leading or trailing newline; an all-nil merge stays nil.
        let parts = [ lhs, rhs ].compactMap { $0 }

        return parts.isEmpty ? nil : parts.joined( separator: "\n" )
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

    private class func parseCommentOnly( string: String ) throws -> String?
    {
        let string = string.rightTrimmingCharacters( in: .fitsPadding )

        return string.isEmpty ? nil : string
    }

    private class func parseValueAndComment( name: String, string: String, options: FITSParsingOptions ) throws -> ( value: Value, comment: String? )
    {
        let string = string.rightTrimmingCharacters( in: .fitsPadding )

        if name == "CONTINUE"
        {
            guard string.count >= 3,
                  string[ string.startIndex ]                              == " ",
                  string[ string.index( string.startIndex, offsetBy: 1 ) ] == " ",
                  string[ string.index( string.startIndex, offsetBy: 2 ) ] == "'"
            else
            {
                throw FITSError.invalidPropertyData( reason: "Invalid CONTINUE property" )
            }

            let ( value, comment ) = try self.parseStringValueAndComment( data: String( string.dropFirst( 2 ) ), options: options )

            return ( .string( value ), comment )
        }
        else if string.count >= 1, string[ string.startIndex ] == "="
        {
            if string.count >= 2, string[ string.index( after: string.startIndex ) ] == " "
            {
                // string is right-trimmed and reaches here only when it has a
                // space at index 1 that is not the last character, so dropping
                // the leading "= " always leaves a non-empty value.
                let data = String( string.dropFirst( 2 ) )

                if data.first == "'"
                {
                    let ( value, comment ) = try self.parseStringValueAndComment( data: data, options: options )

                    return ( .string( value ), comment )
                }
                else if let index = data.firstIndex( of: "/" )
                {
                    let property = String( data[ data.startIndex ..< index ] )
                    let comment  = String( data[ data.index( after: index )... ] )
                    let value    = try self.parseNonStringValue( data: property )

                    return ( value, comment.first == " " ? String( comment.dropFirst() ) : comment )
                }
                else
                {
                    let value = try self.parseNonStringValue( data: data )

                    return ( value, nil )
                }
            }
            else
            {
                let comment = String( string.dropFirst() )

                return ( .undefined, comment.isEmpty ? nil : comment )
            }
        }
        else if let index = string.firstIndex( of: "/" )
        {
            let comment = String( string[ string.index( after: index )... ] ).rightTrimmingCharacters( in: .fitsPadding )

            return ( .undefined, comment.first == " " ? String( comment.dropFirst() ) : comment )
        }
        else
        {
            return ( .undefined, string.isEmpty ? nil : string )
        }
    }

    private class func parseStringValueAndComment( data: String, options: FITSParsingOptions ) throws -> ( value: String, comment: String? )
    {
        guard let first = data.first, first == "'"
        else
        {
            throw FITSError.invalidPropertyData( reason: "Missing start quote" )
        }

        var index = data.index( after: data.startIndex )
        var value = ""

        while index < data.endIndex
        {
            if data[ index ] == "'"
            {
                let next = data.index( after: index )

                if next < data.endIndex && data[ next ] == "'"
                {
                    value.append( "'" )

                    index = data.index( after: next )
                }
                else
                {
                    break
                }
            }
            else
            {
                value.append( data[ index ] )

                index = data.index( after: index )
            }
        }

        if index == data.endIndex
        {
            throw FITSError.invalidPropertyData( reason: "Missing end quote" )
        }

        // rest starts at the closing quote; everything after it, up to the
        // optional "/" comment delimiter, must be blank.
        let afterQuote = data[ data.index( after: index )... ]

        let string = if value.isEmpty
        {
            ""
        }
        else if value.unicodeScalars.allSatisfy( { $0 == " " } )
        {
            " "
        }
        else
        {
            value.rightTrimmingCharacters( in: CharacterSet( charactersIn: " " ) )
        }

        // In strict mode, the bytes between the closing quote and the optional
        // "/" comment delimiter (or end of record) must be blank. Non-strict
        // parsing tolerates noncompliant trailing characters by dropping them.
        let allowJunk = options.contains( .allowTrailingQuoteJunk )

        if let slash = afterQuote.firstIndex( of: "/" )
        {
            guard allowJunk || afterQuote[ afterQuote.startIndex ..< slash ].allSatisfy( { $0 == " " } )
            else
            {
                throw FITSError.invalidPropertyData( reason: "Unexpected characters after closing quote" )
            }

            let comment = afterQuote[ afterQuote.index( after: slash )... ].trimmingCharacters( in: .fitsPadding )

            return ( string, comment )
        }

        guard allowJunk || afterQuote.allSatisfy( { $0 == " " } )
        else
        {
            throw FITSError.invalidPropertyData( reason: "Unexpected characters after closing quote" )
        }

        return ( string, nil )
    }

    private class func parseNonStringValue( data: String ) throws -> Value
    {
        let trimmed = data.trimmingCharacters( in: .fitsPadding )

        guard trimmed.isEmpty == false
        else
        {
            return .undefined
        }

        if let value = self.asLogical( data: trimmed )
        {
            return .logical( value )
        }

        if let value = try self.asInteger( data: trimmed )
        {
            return .integer( value )
        }

        if let value = try self.asFloatingPoint( data: trimmed )
        {
            return .float( value )
        }

        return .unknown( data )
    }

    private class func asLogical( data: String ) -> Bool?
    {
        let data = data.trimmingCharacters( in: .fitsPadding )

        if data == "T"
        {
            return true
        }

        if data == "F"
        {
            return false
        }

        return nil
    }

    private class func asInteger( data: String ) throws -> Int64?
    {
        let data  = data.trimmingCharacters( in: .fitsPadding )
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
        let data  = data.trimmingCharacters( in: .fitsPadding )
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
        let comment = self.comment?.replacingOccurrences( of: "\n", with: "\\n" ) ?? "<nil>"
        let value   = switch self.value
        {
            case .logical( let value ): String( describing: value )
            case .integer( let value ): String( describing: value )
            case .float(   let value ): String( describing: value )
            case .string(  let value ): value
            case .undefined:            "<nil>"
            case .unknown( let value ): value
        }

        return "FITSProperty { name: \( name ), kind: \( self.kind ), value: \( value ), comment: \( comment ) }"
    }
}
