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

/// A single FITS header record: a keyword, its optional value and comment.
///
/// Each property corresponds to one 80-byte header record. Special keywords
/// (`COMMENT`, `HISTORY`, `CONTINUE`) and blank keywords are handled during
/// parsing, and related records can be merged together via ``merge(with:)``.
public class FITSProperty: CustomStringConvertible
{
    /// The keyword name, with trailing padding removed.
    public private( set ) var name: String

    /// The parsed value of the record.
    public private( set ) var value: FITSValue

    /// The record's comment, or `nil` when there is none.
    public private( set ) var comment: String?

    /// Creates a property from one 80-byte record of ASCII data.
    ///
    /// - Parameters:
    ///   - data: The 80 bytes of the record. Must be valid ASCII.
    ///   - options: The parsing options to apply.
    /// - Throws: ``FITSError/invalidPropertyData(reason:)`` if the data is not
    ///   ASCII or the record is malformed.
    public convenience init( data: Data, options: FITSParsingOptions = .lenient ) throws
    {
        guard let string = String( data: data, encoding: .ascii )
        else
        {
            throw FITSError.invalidPropertyData( reason: "Invalid ASCII data" )
        }

        try self.init( string: string, options: options )
    }

    /// Creates a property by parsing one 80-character header record.
    ///
    /// The first 8 characters are the keyword name; the remainder holds the
    /// value and/or comment, parsed according to the keyword and `options`.
    /// `COMMENT`, `HISTORY` and blank keywords carry only a comment.
    ///
    /// - Parameters:
    ///   - string: The record text. Must be exactly 80 characters long.
    ///   - options: The parsing options to apply.
    /// - Throws: ``FITSError/invalidPropertyData(reason:)`` if the record is
    ///   not 80 characters or cannot be parsed.
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

    /// Merges a continuation record into this property in place.
    ///
    /// Supports the three multi-record FITS conventions: appending another
    /// `HISTORY` or `COMMENT` record's text, and continuing a long string
    /// value via a `CONTINUE` record (which requires this property's string to
    /// end with the `&` continuation flag). Comments are joined with newlines.
    ///
    /// - Parameter property: The follow-on record to merge in. Its name must be
    ///   compatible with this property's name.
    /// - Throws: ``FITSError/invalidPropertyData(reason:)`` if the two records
    ///   cannot be merged (mismatched names, wrong value type, or a missing
    ///   continuation flag).
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

    /// Joins two optional comments with a newline, ignoring `nil` sides.
    ///
    /// - Parameters:
    ///   - lhs: The first comment, or `nil`.
    ///   - rhs: The second comment, or `nil`.
    /// - Returns: The joined comment, or `nil` if both sides are `nil`.
    private class func mergedComment( _ lhs: String?, _ rhs: String? ) -> String?
    {
        // Join only the non-nil parts so a nil side never contributes a stray
        // leading or trailing newline; an all-nil merge stays nil.
        let parts = [ lhs, rhs ].compactMap { $0 }

        return parts.isEmpty ? nil : parts.joined( separator: "\n" )
    }

    /// Parses and validates a keyword name from the first 8 characters.
    ///
    /// - Parameter string: The 8-character keyword field.
    /// - Returns: The keyword name with trailing padding removed.
    /// - Throws: ``FITSError/invalidPropertyData(reason:)`` if the name
    ///   contains characters outside ``CharacterSet/fitsKeyword``.
    private class func parseName( string: String ) throws -> String
    {
        let name = string.rightTrimmingCharacters( in: .fitsPadding )

        if name.unicodeScalars.allSatisfy( { CharacterSet.fitsKeyword.contains( $0 ) } ) == false
        {
            throw FITSError.invalidPropertyData( reason: "Invalid property name" )
        }

        return name
    }

    /// Extracts the comment text of a value-less record (`COMMENT`, `HISTORY`,
    /// or a blank keyword).
    ///
    /// - Parameter string: The record text following the 8-character keyword.
    /// - Returns: The trimmed comment, or `nil` if it is blank.
    private class func parseCommentOnly( string: String ) throws -> String?
    {
        let string = string.rightTrimmingCharacters( in: .fitsPadding )

        return string.isEmpty ? nil : string
    }

    /// Parses the value and comment portion of a keyword record.
    ///
    /// Handles `CONTINUE` records, the `= ` value indicator (string, commented
    /// and bare values), and records carrying only a comment.
    ///
    /// - Parameters:
    ///   - name: The keyword name, used to special-case `CONTINUE`.
    ///   - string: The record text following the 8-character keyword.
    ///   - options: The parsing options to apply.
    /// - Returns: The parsed value and its optional comment.
    /// - Throws: ``FITSError/invalidPropertyData(reason:)`` if the value field
    ///   is malformed.
    private class func parseValueAndComment( name: String, string: String, options: FITSParsingOptions ) throws -> ( value: FITSValue, comment: String? )
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

    /// Parses a quoted string value and its trailing comment.
    ///
    /// Handles FITS string escaping (a doubled `''` denotes a literal quote),
    /// preserves a single significant space, and trims insignificant trailing
    /// spaces. In strict mode the characters between the closing quote and the
    /// optional `/` comment delimiter must be blank; ``FITSParsingOptions/allowTrailingQuoteJunk``
    /// relaxes this.
    ///
    /// - Parameters:
    ///   - data: The value field beginning with the opening quote.
    ///   - options: The parsing options to apply.
    /// - Returns: The unescaped string value and its optional comment.
    /// - Throws: ``FITSError/invalidPropertyData(reason:)`` if a quote is
    ///   missing or unexpected characters follow the closing quote in strict
    ///   mode.
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

    /// Classifies a non-string value field into a ``FITSValue``.
    ///
    /// Tries, in order: logical (`T`/`F`), integer, then floating point. An
    /// empty field becomes ``FITSValue/undefined``; anything matching no
    /// grammar (or an integer that overflows `Int64`) becomes
    /// ``FITSValue/unknown(_:)`` preserving the original literal.
    ///
    /// - Parameter data: The value field with surrounding padding.
    /// - Returns: The classified value.
    /// - Throws: An error if a regular expression fails to build.
    private class func parseNonStringValue( data: String ) throws -> FITSValue
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

        if try self.matchesInteger( data: trimmed )
        {
            if let value = Int64( trimmed )
            {
                return .integer( value )
            }

            // Matches the integer grammar but overflows Int64: keep the exact literal as .unknown
            return .unknown( data )
        }

        if let value = try self.asFloatingPoint( data: trimmed )
        {
            return .float( value )
        }

        return .unknown( data )
    }

    /// Interprets a value field as a FITS logical.
    ///
    /// - Parameter data: The value field.
    /// - Returns: `true` for `T`, `false` for `F`, or `nil` if it is neither.
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

    /// Reports whether a value field matches the FITS integer grammar.
    ///
    /// Matches an optional sign followed by one or more digits. Note this only
    /// checks the grammar; the literal may still overflow `Int64`.
    ///
    /// - Parameter data: The value field.
    /// - Returns: `true` if the field is a well-formed integer literal.
    /// - Throws: An error if the regular expression fails to build.
    private class func matchesInteger( data: String ) throws -> Bool
    {
        let data  = data.trimmingCharacters( in: .fitsPadding )
        let regex = try NSRegularExpression( pattern: #"^[+-]?\d+$"#, options: [] )
        let range = NSRange( location: 0, length: data.utf16.count )

        return regex.firstMatch( in: data, options: [], range: range ) != nil
    }

    /// Interprets a value field as a FITS floating-point number.
    ///
    /// Accepts the FITS real grammar including `E`/`D` exponents; the `D`
    /// (double-precision) exponent marker is normalized to `E` before
    /// conversion.
    ///
    /// - Parameter data: The value field.
    /// - Returns: The parsed value, or `nil` if it is not a floating-point literal.
    /// - Throws: An error if the regular expression fails to build.
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

    /// A single-line, human-readable summary of the property.
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

        return "FITSProperty { name: \( name ), kind: \( self.value.kind ), value: \( value ), comment: \( comment ) }"
    }
}
