/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Jean-David Gadina - www.xs-labs.com
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
    ///
    /// The name is fixed at construction: it is validated (and, under a lenient
    /// serialization option, coerced) when the property is created, and cannot be
    /// changed afterwards. To use a different keyword, build a new property.
    public private( set ) var name: String

    /// The value of the record.
    ///
    /// Settable so a constructed or parsed property can be edited in place. Any
    /// ``FITSValue`` is accepted; a value that cannot be rendered (for example a
    /// non-finite ``FITSValue/float(_:)``) is rejected later, on serialization.
    /// Editing it marks the owning ``FITSSection`` (if any) as needing
    /// re-serialization.
    public var value: FITSValue
    {
        didSet
        {
            // Reassigning the same value must not dirty the section, so an
            // otherwise-untouched parsed section keeps re-emitting its retained
            // bytes byte-for-byte.
            guard self.value != oldValue
            else
            {
                return
            }

            self.section?.markNeedsSerialization()
        }
    }

    /// The record's comment, or `nil` when there is none.
    ///
    /// Settable so a constructed or parsed property can be edited in place. For a
    /// commentary keyword (`COMMENT`, `HISTORY` or the blank keyword) the comment
    /// is the record's only payload, and embedded newlines render as one card per
    /// line on serialization. Editing it marks the owning ``FITSSection`` (if any)
    /// as needing re-serialization.
    public var comment: String?
    {
        didSet
        {
            // Reassigning the same comment must not dirty the section, so an
            // otherwise-untouched parsed section keeps re-emitting its retained
            // bytes byte-for-byte.
            guard self.comment != oldValue
            else
            {
                return
            }

            self.section?.markNeedsSerialization()
        }
    }

    /// The section that owns this property, or `nil` if it belongs to none.
    ///
    /// Set when the property is added to a ``FITSSection`` — on construction from
    /// a model, on mutation, or when a parsed section is finalized — and used so
    /// that editing ``value`` or ``comment`` in place marks that section as
    /// needing re-serialization. It is `weak` to avoid a reference cycle, since a
    /// section holds its properties strongly.
    internal weak var section: FITSSection?

    /// Creates a property from one 80-byte record of ASCII data.
    ///
    /// - Parameters:
    ///   - data: The 80 bytes of the record. Must be valid ASCII.
    ///   - options: The parsing options to apply.
    /// - Throws: ``FITSError/invalidPropertyData(reason:)`` if the data is not
    ///   ASCII or the record is malformed.
    public convenience init( data: Data, options: FITSParsingOptions ) throws
    {
        guard let string = String( data: data, encoding: .ascii )
        else
        {
            throw FITSError.invalidPropertyData( reason: "Invalid ASCII data" )
        }

        try self.init( string: string, options: options )
    }

    /// Creates a property by parsing one 80-character ASCII header record.
    ///
    /// The first 8 characters are the keyword name; the remainder holds the
    /// value and/or comment, parsed according to the keyword and `options`.
    /// `COMMENT`, `HISTORY` and blank keywords carry only a comment.
    ///
    /// The record must be ASCII: a FITS record is 80 *bytes*, so non-ASCII
    /// characters would make the Character-based length and slicing diverge
    /// from the byte model.
    ///
    /// - Parameters:
    ///   - string: The record text. Must be exactly 80 ASCII characters long.
    ///   - options: The parsing options to apply.
    /// - Throws: ``FITSError/invalidPropertyData(reason:)`` if the record is
    ///   not 80 characters, is not ASCII, or cannot be parsed.
    public init( string: String, options: FITSParsingOptions ) throws
    {
        guard string.count == FITSFile.cardSize
        else
        {
            throw FITSError.invalidPropertyData( reason: "Invalid property data length (\( string.count ))" )
        }

        guard string.unicodeScalars.allSatisfy( { $0.isASCII } )
        else
        {
            throw FITSError.invalidPropertyData( reason: "Record must be ASCII" )
        }

        let name = try FITSProperty.parseName( string: String( string.prefix( FITSFile.keywordLength ) ), options: options )

        if name == "HISTORY" || name == "COMMENT"
        {
            self.name    = name
            self.value   = .undefined
            self.comment = try FITSProperty.parseCommentOnly( string: String( string.dropFirst( FITSFile.keywordLength ) ), options: options )
        }
        else if name.isEmpty
        {
            self.name    = name
            self.value   = .undefined
            self.comment = try FITSProperty.parseCommentOnly( string: String( string.dropFirst( FITSFile.keywordLength ) ), options: options )
        }
        else
        {
            let ( value, comment ) = try FITSProperty.parseValueAndComment( name: name, string: String( string.dropFirst( FITSFile.keywordLength ) ), options: options )
            self.name              = name
            self.value             = value
            self.comment           = comment
        }
    }

    /// Creates a property by parsing a keyword's *raw FITS value field*.
    ///
    /// Legacy carriers such as XISF store a FITS keyword's value as the raw,
    /// still-formatted value field — a quoted string like `'M 42'`, a number, or a
    /// logical `T`/`F` — kept separately from the name and comment rather than as a
    /// typed value. This initializer interprets that field with the **same** value
    /// parser the full-card ``init(string:options:)`` uses, so quote stripping,
    /// doubled-`''` unescaping and numeric/logical classification behave
    /// identically — without reconstructing and padding a full 80-character card,
    /// and so with no length or truncation limit on the field.
    ///
    /// The field is the value alone: no `=` value indicator is expected, and an
    /// unquoted field containing a `/` is split into value and comment exactly as
    /// in a real card. A `nil` field yields ``FITSValue/undefined``, as for a
    /// value-less keyword.
    ///
    /// - Parameters:
    ///   - name: The keyword name, validated against the FITS keyword character
    ///     set (as when parsing a card).
    ///   - rawValue: The raw FITS value field, or `nil` for a value-less keyword.
    ///   - comment: The keyword's comment. When `nil`, a comment parsed from the
    ///     field (an unquoted value's trailing `/comment`) is kept instead; when
    ///     given, it takes precedence.
    ///   - options: The parsing options governing value interpretation.
    /// - Throws: ``FITSError/invalidPropertyData(reason:)`` if the name is not a
    ///   valid keyword or the value field is malformed.
    public init( name: String, rawValue: String?, comment: String? = nil, options: FITSParsingOptions ) throws
    {
        let parsedName = try FITSProperty.parseName( string: name, options: options )

        guard let rawValue
        else
        {
            self.name    = parsedName
            self.value   = .undefined
            self.comment = comment

            return
        }

        let ( value, parsedComment ) = try FITSProperty.parseValueAndComment( name: parsedName, string: "= \( rawValue )", options: options )
        self.name    = parsedName
        self.value   = value
        self.comment = comment ?? parsedComment
    }

    /// Creates a property from a keyword, a value and an optional comment.
    ///
    /// This is the building block for constructing header records from scratch
    /// and for editing parsed ones. The keyword is validated against the FITS
    /// keyword character set via ``normalizedKeyword(_:options:)``: under a strict
    /// option an out-of-charset or over-length name is rejected, while a lenient
    /// option upper-cases an otherwise-valid name. The blank keyword and the
    /// commentary keywords (`COMMENT`, `HISTORY`) are accepted.
    ///
    /// - Parameters:
    ///   - name: The keyword name.
    ///   - value: The record's value; use ``FITSValue/undefined`` for a keyword
    ///     that carries no value.
    ///   - comment: The record's comment, or `nil` for none.
    ///   - options: The serialization options governing keyword validation:
    ///     ``FITSSerializationOptions/strict`` rejects an invalid keyword, while a
    ///     lenient option may coerce it.
    /// - Throws: ``FITSError/cannotSerialize(reason:)`` if the keyword is invalid
    ///   and cannot be coerced.
    public init( name: String, value: FITSValue, comment: String? = nil, options: FITSSerializationOptions ) throws
    {
        self.name    = try FITSProperty.normalizedKeyword( name, options: options )
        self.value   = value
        self.comment = comment
    }

    /// Creates a property holding a logical (boolean) value.
    ///
    /// - Parameters:
    ///   - name: The keyword name.
    ///   - logical: The boolean value, rendered `T` or `F`.
    ///   - comment: The record's comment, or `nil` for none.
    ///   - options: The serialization options governing keyword validation:
    ///     ``FITSSerializationOptions/strict`` rejects an invalid keyword, while a
    ///     lenient option may coerce it.
    /// - Throws: ``FITSError/cannotSerialize(reason:)`` if the keyword is invalid
    ///   and cannot be coerced.
    public convenience init( name: String, logical: Bool, comment: String? = nil, options: FITSSerializationOptions ) throws
    {
        try self.init( name: name, value: .logical( logical ), comment: comment, options: options )
    }

    /// Creates a property holding an integer value.
    ///
    /// - Parameters:
    ///   - name: The keyword name.
    ///   - integer: The integer value.
    ///   - comment: The record's comment, or `nil` for none.
    ///   - options: The serialization options governing keyword validation:
    ///     ``FITSSerializationOptions/strict`` rejects an invalid keyword, while a
    ///     lenient option may coerce it.
    /// - Throws: ``FITSError/cannotSerialize(reason:)`` if the keyword is invalid
    ///   and cannot be coerced.
    public convenience init( name: String, integer: Int64, comment: String? = nil, options: FITSSerializationOptions ) throws
    {
        try self.init( name: name, value: .integer( integer ), comment: comment, options: options )
    }

    /// Creates a property holding a floating-point value.
    ///
    /// - Parameters:
    ///   - name: The keyword name.
    ///   - float: The floating-point value. A non-finite value is accepted here
    ///     but rejected on serialization.
    ///   - comment: The record's comment, or `nil` for none.
    ///   - options: The serialization options governing keyword validation:
    ///     ``FITSSerializationOptions/strict`` rejects an invalid keyword, while a
    ///     lenient option may coerce it.
    /// - Throws: ``FITSError/cannotSerialize(reason:)`` if the keyword is invalid
    ///   and cannot be coerced.
    public convenience init( name: String, float: Double, comment: String? = nil, options: FITSSerializationOptions ) throws
    {
        try self.init( name: name, value: .float( float ), comment: comment, options: options )
    }

    /// Creates a property holding a string value.
    ///
    /// - Parameters:
    ///   - name: The keyword name.
    ///   - string: The string value; it is single-quoted and, when too long for
    ///     one card, split across `CONTINUE` records on serialization.
    ///   - comment: The record's comment, or `nil` for none.
    ///   - options: The serialization options governing keyword validation:
    ///     ``FITSSerializationOptions/strict`` rejects an invalid keyword, while a
    ///     lenient option may coerce it.
    /// - Throws: ``FITSError/cannotSerialize(reason:)`` if the keyword is invalid
    ///   and cannot be coerced.
    public convenience init( name: String, string: String, comment: String? = nil, options: FITSSerializationOptions ) throws
    {
        try self.init( name: name, value: .string( string ), comment: comment, options: options )
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
    internal func merge( with property: FITSProperty ) throws
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
    /// Only base FITS 4.0 keywords are recognized; the `HIERARCH` and other
    /// long-keyword conventions are out of scope and treated as ordinary 8-byte
    /// keywords. Names must be left-justified: a leading space is not a member
    /// of ``CharacterSet/fitsKeyword``, so a non-left-justified name is rejected.
    ///
    /// - Parameters:
    ///   - string: The 8-character keyword field.
    ///   - options: The parsing options to apply.
    /// - Returns: The keyword name with trailing padding removed.
    /// - Throws: ``FITSError/invalidPropertyData(reason:)`` if the name
    ///   contains characters outside ``CharacterSet/fitsKeyword``.
    private class func parseName( string: String, options: FITSParsingOptions ) throws -> String
    {
        let padding = options.contains( .allowNulPadding ) ? CharacterSet.fitsPaddingWithNul : .fitsPadding
        let name    = string.rightTrimmingCharacters( in: padding )

        if name.unicodeScalars.allSatisfy( { CharacterSet.fitsKeyword.contains( $0 ) } ) == false
        {
            throw FITSError.invalidPropertyData( reason: "Invalid property name" )
        }

        return name
    }

    /// Extracts the comment text of a value-less record (`COMMENT`, `HISTORY`,
    /// or a blank keyword).
    ///
    /// - Parameters:
    ///   - string: The record text following the 8-character keyword.
    ///   - options: The parsing options to apply.
    /// - Returns: The trimmed comment, or `nil` if it is blank.
    private class func parseCommentOnly( string: String, options: FITSParsingOptions ) throws -> String?
    {
        let padding = options.contains( .allowNulPaddingInValues ) ? CharacterSet.fitsPaddingWithNul : .fitsPadding
        let string  = string.rightTrimmingCharacters( in: padding )

        return string.isEmpty ? nil : string
    }

    /// Normalizes the comment text following the `/` delimiter.
    ///
    /// A single space conventionally separates `/` from the comment; it is
    /// dropped while any further leading spaces are kept, so a comment
    /// normalizes identically whether or not its value is a string.
    ///
    /// - Parameter text: The record text following the `/` delimiter.
    /// - Returns: The comment with one leading delimiter space removed.
    private class func parsedComment( from text: some StringProtocol ) -> String
    {
        text.first == " " ? String( text.dropFirst() ) : String( text )
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
        let padding = options.contains( .allowNulPaddingInValues ) ? CharacterSet.fitsPaddingWithNul : .fitsPadding
        let string  = string.rightTrimmingCharacters( in: padding )

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
                    let value    = try self.parseNonStringValue( data: property, options: options )

                    return ( value, FITSProperty.parsedComment( from: data[ data.index( after: index )... ] ) )
                }
                else
                {
                    let value = try self.parseNonStringValue( data: data, options: options )

                    return ( value, nil )
                }
            }
            else
            {
                // string[0] is "=" but is not followed by a space. A bare "="
                // (a "= " indicator whose value is empty, trimmed to "=") is
                // valid; "=x" means the mandatory space after the value
                // indicator is missing, which strict parsing rejects.
                if string.count >= 2, options.contains( .allowMissingValueIndicatorSpace ) == false
                {
                    throw FITSError.invalidPropertyData( reason: "Missing space after value indicator" )
                }

                let comment = String( string.dropFirst() )

                return ( .undefined, comment.isEmpty ? nil : comment )
            }
        }
        else if let index = string.firstIndex( of: "/" )
        {
            return ( .undefined, FITSProperty.parsedComment( from: string[ string.index( after: index )... ] ) )
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

            return ( string, FITSProperty.parsedComment( from: afterQuote[ afterQuote.index( after: slash )... ] ) )
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
    /// - Parameters:
    ///   - data: The value field with surrounding padding.
    ///   - options: The parsing options to apply.
    /// - Returns: The classified value.
    /// - Throws: An error if a regular expression fails to build.
    private class func parseNonStringValue( data: String, options: FITSParsingOptions ) throws -> FITSValue
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

            // Matches the integer grammar but overflows Int64: keep the trimmed literal as .unknown
            return .unknown( trimmed )
        }

        if let value = try self.asFloatingPoint( data: trimmed, options: options )
        {
            // Matches the float grammar but overflows Double (±inf): keep the
            // exact literal as .unknown rather than a meaningless infinity.
            guard value.isFinite
            else
            {
                return .unknown( trimmed )
            }

            return .float( value )
        }

        return .unknown( trimmed )
    }

    /// Interprets a value field as a FITS logical.
    ///
    /// - Parameter data: The value field, already trimmed of surrounding padding.
    /// - Returns: `true` for `T`, `false` for `F`, or `nil` if it is neither.
    private class func asLogical( data: String ) -> Bool?
    {
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

    /// The compiled FITS integer-literal pattern, built once and shared. The
    /// `Result` carries a compile failure through the caller's `throws`.
    private static let integerRegex = Result { try NSRegularExpression( pattern: #"^[+-]?\d+$"#, options: [] ) }

    /// The compiled FITS floating-point-literal pattern, built once and shared.
    private static let floatingPointRegex = Result { try NSRegularExpression( pattern: #"^[+-]?(?:\d+\.?\d*|\.\d+)([ED][+-]?\d+)?$"#, options: [] ) }

    /// The floating-point pattern that also admits lowercase `e`/`d` exponent
    /// markers, used when ``FITSParsingOptions/allowLowercaseExponents`` is set.
    private static let floatingPointLowercaseExponentRegex = Result { try NSRegularExpression( pattern: #"^[+-]?(?:\d+\.?\d*|\.\d+)([EeDd][+-]?\d+)?$"#, options: [] ) }

    /// Reports whether a value field matches the FITS integer grammar.
    ///
    /// Matches an optional sign followed by one or more digits. Note this only
    /// checks the grammar; the literal may still overflow `Int64`.
    ///
    /// - Parameter data: The value field, already trimmed of surrounding padding.
    /// - Returns: `true` if the field is a well-formed integer literal.
    /// - Throws: An error if the regular expression fails to build.
    private class func matchesInteger( data: String ) throws -> Bool
    {
        let regex = try FITSProperty.integerRegex.get()
        let range = NSRange( location: 0, length: data.utf16.count )

        return regex.firstMatch( in: data, options: [], range: range ) != nil
    }

    /// Interprets a value field as a FITS floating-point number.
    ///
    /// Accepts the FITS real grammar including `E`/`D` exponents, plus lowercase
    /// `e`/`d` when ``FITSParsingOptions/allowLowercaseExponents`` is set. The
    /// `D`/`d` (double-precision) exponent marker is normalized to `E` before
    /// conversion.
    ///
    /// - Parameters:
    ///   - data: The value field, already trimmed of surrounding padding.
    ///   - options: The parsing options to apply.
    /// - Returns: The parsed value, or `nil` if it is not a floating-point literal.
    /// - Throws: An error if the regular expression fails to build.
    private class func asFloatingPoint( data: String, options: FITSParsingOptions ) throws -> Double?
    {
        let regex = options.contains( .allowLowercaseExponents ) ? try FITSProperty.floatingPointLowercaseExponentRegex.get() : try FITSProperty.floatingPointRegex.get()
        let range = NSRange( location: 0, length: data.utf16.count )

        if let _ = regex.firstMatch( in: data, options: [], range: range )
        {
            return Double( data.replacingOccurrences( of: "d", with: "e" ).replacingOccurrences( of: "D", with: "E" ) )
        }

        return nil
    }

    /// Renders this property to one or more standards-compliant 80-byte cards —
    /// the inverse of the record parser.
    ///
    /// A value keyword yields a single fixed-format card: the keyword left-
    /// justified in the 8-byte field, the `= ` value indicator, the value
    /// literal (scalars right-justified to byte 30, strings opening at byte 11),
    /// an optional `/` comment, blank-padded to 80 bytes. `COMMENT`, `HISTORY`
    /// and blank keywords yield one commentary card per line of their comment,
    /// and a string value too long for a single card is split across `CONTINUE`
    /// records.
    ///
    /// - Parameter options: The serialization options to apply.
    /// - Returns: The rendered cards, each exactly ``FITSFile/cardSize`` bytes.
    /// - Throws: ``FITSError/cannotSerialize(reason:)`` if the keyword is invalid
    ///   or a record would exceed the card width, or
    ///   ``FITSError/invalidValueForSerialization(reason:)`` from the value
    ///   renderer.
    public func serialized( options: FITSSerializationOptions ) throws -> [ String ]
    {
        let name = try FITSProperty.normalizedKeyword( self.name, options: options )

        if name == "COMMENT" || name == "HISTORY" || name.isEmpty
        {
            return try self.serializedCommentaryCards( name: name )
        }

        if name == "CONTINUE"
        {
            guard case .string = self.value
            else
            {
                throw FITSError.cannotSerialize( reason: "A CONTINUE record requires a string value" )
            }

            return [ try FITSProperty.padCard( "CONTINUE  \( try self.value.serialized() )\( self.serializedComment() )" ) ]
        }

        if case .string( let string ) = self.value
        {
            return try self.serializedStringCards( name: name, string: string )
        }

        return [ try self.serializedScalarCard( name: name ) ]
    }

    /// Normalizes and validates a keyword name for serialization.
    ///
    /// A name already within ``CharacterSet/fitsKeyword`` (including the empty
    /// blank keyword) is returned unchanged. Otherwise, if
    /// ``FITSSerializationOptions/coerceInvalidKeywords`` is set, the name is
    /// upper-cased and re-checked; a name still outside the set, or longer than
    /// ``FITSFile/keywordLength``, is rejected.
    ///
    /// - Parameters:
    ///   - name: The keyword name to normalize.
    ///   - options: The serialization options to apply.
    /// - Returns: The normalized keyword name.
    /// - Throws: ``FITSError/cannotSerialize(reason:)`` if the name is too long
    ///   or cannot be made valid.
    internal static func normalizedKeyword( _ name: String, options: FITSSerializationOptions ) throws -> String
    {
        guard name.count <= FITSFile.keywordLength
        else
        {
            throw FITSError.cannotSerialize( reason: "Keyword name exceeds \( FITSFile.keywordLength ) characters: \( name )" )
        }

        if name.unicodeScalars.allSatisfy( { CharacterSet.fitsKeyword.contains( $0 ) } )
        {
            return name
        }

        guard options.contains( .coerceInvalidKeywords )
        else
        {
            throw FITSError.cannotSerialize( reason: "Invalid keyword name: \( name )" )
        }

        let coerced = name.uppercased()

        guard coerced.count <= FITSFile.keywordLength, coerced.unicodeScalars.allSatisfy( { CharacterSet.fitsKeyword.contains( $0 ) } )
        else
        {
            throw FITSError.cannotSerialize( reason: "Invalid keyword name: \( name )" )
        }

        return coerced
    }

    /// Renders a commentary property (`COMMENT`, `HISTORY` or the blank keyword)
    /// to one card per line of its comment.
    ///
    /// - Parameter name: The already-normalized keyword name.
    /// - Returns: The commentary cards. A property with no comment yields one
    ///   card holding just the keyword field.
    /// - Throws: ``FITSError/cannotSerialize(reason:)`` if a line does not fit
    ///   the card width.
    private func serializedCommentaryCards( name: String ) throws -> [ String ]
    {
        let field = name.padding( toLength: FITSFile.keywordLength, withPad: " ", startingAt: 0 )
        let lines = self.comment.map { $0.components( separatedBy: "\n" ) } ?? [ "" ]

        return try lines.map { try FITSProperty.padCard( field + $0 ) }
    }

    /// Renders a non-string value keyword to a single fixed-format card.
    ///
    /// - Parameter name: The already-normalized keyword name.
    /// - Returns: The rendered card.
    /// - Throws: ``FITSError/cannotSerialize(reason:)`` if the record exceeds the
    ///   card width, or an error from the value renderer.
    private func serializedScalarCard( name: String ) throws -> String
    {
        let field = name.padding( toLength: FITSFile.keywordLength, withPad: " ", startingAt: 0 )
        let value = self.value.kind == .undefined ? "" : FITSProperty.rightJustified( try self.value.serialized() )
        let body  = "\( field )= \( value )\( self.serializedComment() )"

        return try FITSProperty.padCard( body )
    }

    /// Renders a string value keyword, splitting a value too long for one card
    /// across `CONTINUE` records per the FITS long-string convention.
    ///
    /// - Parameters:
    ///   - name: The already-normalized keyword name.
    ///   - string: The string value to render.
    /// - Returns: The rendered cards.
    /// - Throws: ``FITSError/cannotSerialize(reason:)`` if a record exceeds the
    ///   card width, or an error from the value renderer.
    private func serializedStringCards( name: String, string: String ) throws -> [ String ]
    {
        // The XTENSION value must be padded to eight characters (FITS 4.0 §4.2.1).
        let content = name == "XTENSION" ? string.padding( toLength: max( FITSFile.keywordLength, string.count ), withPad: " ", startingAt: 0 ) : string
        let field   = name.padding( toLength: FITSFile.keywordLength, withPad: " ", startingAt: 0 )
        let literal = try FITSValue.string( content ).serialized()
        let single  = "\( field )= \( literal )\( self.serializedComment() )"

        if single.count <= FITSFile.cardSize
        {
            return [ try FITSProperty.padCard( single ) ]
        }

        return try self.serializedContinuedString( name: name, content: content )
    }

    /// Splits a long string value into a first value card plus `CONTINUE`
    /// records, per the FITS long-string convention (FITS 4.0 §4.2.1).
    ///
    /// Each substring, once its interior quotes are doubled and it is enclosed
    /// in quotes, fits the value field; every substring but the last carries a
    /// trailing `&` continuation flag. The comment is placed on the last value
    /// card when it fits there; otherwise every value card is flagged and the
    /// comment trails on its own `CONTINUE` card carrying an empty string, so a
    /// long value that also has a comment still serializes.
    ///
    /// - Parameters:
    ///   - name: The already-normalized keyword name.
    ///   - content: The full string value to split.
    /// - Returns: The rendered cards.
    /// - Throws: ``FITSError/cannotSerialize(reason:)`` if a record exceeds the
    ///   card width, or an error from the value renderer.
    private func serializedContinuedString( name: String, content: String ) throws -> [ String ]
    {
        let field    = name.padding( toLength: FITSFile.keywordLength, withPad: " ", startingAt: 0 )
        let comment  = self.serializedComment()
        let pieces   = FITSProperty.chunkedStringContent( content )
        let lastBody = try FITSProperty.continuationBody( field: field, index: pieces.count - 1, piece: pieces[ pieces.count - 1 ], flagged: false, comment: comment )

        if lastBody.count <= FITSFile.cardSize
        {
            return try pieces.enumerated().map
            {
                index, piece in

                let isLast = index == pieces.count - 1

                return try FITSProperty.padCard( try FITSProperty.continuationBody( field: field, index: index, piece: piece, flagged: isLast == false, comment: isLast ? comment : "" ) )
            }
        }

        let cards = try pieces.enumerated().map
        {
            index, piece in try FITSProperty.padCard( try FITSProperty.continuationBody( field: field, index: index, piece: piece, flagged: true, comment: "" ) )
        }

        return cards + [ try FITSProperty.padCard( "CONTINUE  ''\( comment )" ) ]
    }

    /// Splits string content into substrings that each fit the value field once
    /// escaped, quoted and flagged.
    ///
    /// - Parameter content: The string value to split. An empty value yields a
    ///   single empty substring.
    /// - Returns: The substrings, in order.
    private static func chunkedStringContent( _ content: String ) -> [ String ]
    {
        // The 10-byte prefix (keyword + "= ", or "CONTINUE" plus two spaces)
        // leaves bytes 11–80 = 70 columns; reserve two for the enclosing quotes
        // and one for the trailing "&" flag, giving 67 content characters.
        let capacity = FITSFile.cardSize - ( FITSFile.keywordLength + 2 ) - 3

        return content.isEmpty ? [ "" ] : content.reduce( into: [ String ]() )
        {
            pieces, character in

            let candidate = ( pieces.last ?? "" ) + String( character )
            let escaped   = candidate.count + candidate.filter { $0 == "'" }.count

            if pieces.isEmpty == false, escaped <= capacity
            {
                pieces[ pieces.count - 1 ] = candidate
            }
            else
            {
                pieces.append( String( character ) )
            }
        }
    }

    /// Builds one continuation record body from a substring.
    ///
    /// - Parameters:
    ///   - field: The padded keyword field used on the first record.
    ///   - index: The substring's position; index 0 is the value card, the rest
    ///     are `CONTINUE` records.
    ///   - piece: The substring content.
    ///   - flagged: Whether to append the `&` continuation flag before the
    ///     closing quote.
    ///   - comment: A trailing comment suffix, or the empty string for none.
    /// - Returns: The unpadded record body.
    /// - Throws: An error from the value renderer.
    private static func continuationBody( field: String, index: Int, piece: String, flagged: Bool, comment: String ) throws -> String
    {
        let prefix  = index == 0 ? "\( field )= " : "CONTINUE  "
        let literal = try FITSValue.string( piece ).serialized()
        let value   = flagged ? "\( literal.dropLast() )&'" : literal

        return "\( prefix )\( value )\( comment )"
    }

    /// Right-justifies a scalar value literal within the fixed-format value
    /// field. A literal already at least ``FITSFile/fixedValueFieldWidth`` long
    /// is returned unchanged (free-format overflow).
    ///
    /// - Parameter literal: The value literal to place.
    /// - Returns: The literal padded on the left to the fixed field width.
    private static func rightJustified( _ literal: String ) -> String
    {
        guard literal.count < FITSFile.fixedValueFieldWidth
        else
        {
            return literal
        }

        return String( repeating: " ", count: FITSFile.fixedValueFieldWidth - literal.count ) + literal
    }

    /// Renders this property's comment as a card suffix.
    ///
    /// The single space after the `/` mirrors the one dropped by the parser, so
    /// the comment round-trips.
    ///
    /// - Returns: ` / <comment>` when a comment is present, otherwise `""`.
    private func serializedComment() -> String
    {
        self.comment.map { " / \( $0 )" } ?? ""
    }

    /// Pads a rendered record to the full card width, or fails if it is too long.
    ///
    /// - Parameter body: The record text.
    /// - Returns: The space-padded ``FITSFile/cardSize``-byte card.
    /// - Throws: ``FITSError/cannotSerialize(reason:)`` if `body` exceeds the
    ///   card width.
    private static func padCard( _ body: String ) throws -> String
    {
        guard body.count <= FITSFile.cardSize
        else
        {
            throw FITSError.cannotSerialize( reason: "Record exceeds \( FITSFile.cardSize ) characters: \( body )" )
        }

        return body.padding( toLength: FITSFile.cardSize, withPad: " ", startingAt: 0 )
    }

    /// A single-line, human-readable summary of the property.
    public var description: String
    {
        let name    = self.name.padding( toLength: FITSFile.keywordLength, withPad: " ", startingAt: 0 )
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
