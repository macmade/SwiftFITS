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
@testable import SwiftFITS
import Testing

struct Test_FITSProperty
{
    @Test
    func initWithData() async throws
    {
        try #require( throws: FITSError.self ) { try FITSProperty( data: Data( repeating: 0xFF, count: 80 ), options: .lenient ) }
        try #require( throws: FITSError.self ) { try FITSProperty( data: Data( repeating: 0x20, count: 79 ), options: .lenient ) }
        try #require( throws: FITSError.self ) { try FITSProperty( data: Data( repeating: 0x20, count: 81 ), options: .lenient ) }

        let property = try FITSProperty( data: Data( repeating: 0x20, count: 80 ), options: .lenient )

        #expect( property.name       == "" )
        #expect( property.value      == .undefined )
        #expect( property.comment    == nil )
        #expect( property.value.kind == .undefined )
    }

    @Test
    func initWithString() async throws
    {
        try #require( throws: FITSError.self ) { try FITSProperty( string: String( repeating: "\u{FF}", count: 80 ), options: .lenient ) }
        try #require( throws: FITSError.self ) { try FITSProperty( string: String( repeating: "\u{20}", count: 79 ), options: .lenient ) }
        try #require( throws: FITSError.self ) { try FITSProperty( string: String( repeating: "\u{20}", count: 81 ), options: .lenient ) }

        let property = try FITSProperty( string: String( repeating: "\u{20}", count: 80 ), options: .lenient )

        #expect( property.name       == "" )
        #expect( property.value      == .undefined )
        #expect( property.comment    == nil )
        #expect( property.value.kind == .undefined )
    }

    @Test
    func initWithRawValueParsesAStringUnquoted() async throws
    {
        let property = try FITSProperty( name: "OBJECT", rawValue: "'M 42'", options: .lenient )

        #expect( property.name       == "OBJECT" )
        #expect( property.value      == .string( "M 42" ) )
        #expect( property.value.kind == .string )
    }

    @Test
    func initWithRawValueParsesNumbersAndLogicals() async throws
    {
        #expect( try FITSProperty( name: "EXPTIME", rawValue: "300",  options: .lenient ).value == .integer( 300 ) )
        #expect( try FITSProperty( name: "GAIN",    rawValue: "1.25", options: .lenient ).value == .float( 1.25 ) )
        #expect( try FITSProperty( name: "SIMPLE",  rawValue: "T",    options: .lenient ).value == .logical( true ) )
        #expect( try FITSProperty( name: "EXTEND",  rawValue: "F",    options: .lenient ).value == .logical( false ) )
    }

    @Test
    func initWithRawValueUnescapesDoubledQuotes() async throws
    {
        let property = try FITSProperty( name: "OBSERVER", rawValue: "'O''Brien'", options: .lenient )

        #expect( property.value == .string( "O'Brien" ) )
    }

    @Test
    func initWithRawValueHasNoCardLengthLimit() async throws
    {
        // A string field far longer than a full 80-character card would allow:
        // parsing the value field directly has no length or truncation limit, so
        // the whole value survives (the hand-built-card path used to bail out).
        let text     = String( repeating: "A", count: 200 )
        let property = try FITSProperty( name: "OBJECT", rawValue: "'\( text )'", options: .lenient )

        #expect( property.value == .string( text ) )
    }

    @Test
    func initWithNilRawValueIsUndefined() async throws
    {
        let property = try FITSProperty( name: "OBJECT", rawValue: nil, comment: "a note", options: .lenient )

        #expect( property.name    == "OBJECT" )
        #expect( property.value   == .undefined )
        #expect( property.comment == "a note" )
    }

    @Test
    func initWithRawValuePrefersAnExplicitCommentOverAParsedOne() async throws
    {
        // An unquoted value field may carry a trailing "/comment": an explicit
        // comment argument wins, and a nil one falls back to the parsed comment.
        let explicit = try FITSProperty( name: "EXPTIME", rawValue: "300 / seconds", comment: "given", options: .lenient )
        let parsed   = try FITSProperty( name: "EXPTIME", rawValue: "300 / seconds", options: .lenient )

        #expect( explicit.value   == .integer( 300 ) )
        #expect( explicit.comment == "given" )
        #expect( parsed.value     == .integer( 300 ) )
        #expect( parsed.comment   == "seconds" )
    }

    @Test
    func initWithRawValueRejectsAnInvalidName() async throws
    {
        #expect( throws: FITSError.self )
        {
            try FITSProperty( name: "BAD NAME", rawValue: "1", options: .lenient )
        }
    }

    @Test
    func initWithStringRejectsNonASCII() async throws
    {
        // 80 grapheme clusters, but a non-ASCII character makes this more than
        // 80 bytes, so it does not correspond to a valid 80-byte record. The
        // Character-based length check would otherwise let it through.
        let record = "COMMENT é" + String( repeating: "\u{20}", count: 71 )

        try #require( record.count == 80 )
        #expect( throws: FITSError.self ) { try FITSProperty( string: record, options: .lenient ) }

        // A valid 80-character ASCII record is still accepted.
        let ascii = "COMMENT Hello" + String( repeating: "\u{20}", count: 67 )

        try #require( ascii.count == 80 )
        #expect( throws: Never.self ) { try FITSProperty( string: ascii, options: .lenient ) }
    }

    @Test
    func initWithWrongLengthReportsLengthInMessage() async throws
    {
        do
        {
            _ = try FITSProperty( string: String( repeating: "\u{20}", count: 79 ), options: .lenient )

            Issue.record( "Expected FITSProperty to reject a 79-character record" )
        }
        catch let error as FITSError
        {
            #expect( error.errorDescription == "Invalid property data: Invalid property data length (79)" )
        }
    }

    @Test
    func name() async throws
    {
        let tests: [ ( data: String, name: String ) ] = [
            ( "ABCD        ", "ABCD"     ),
            ( "ABCDEFGH    ", "ABCDEFGH" ),
            ( "ABCDEFGHIJKL", "ABCDEFGH" ),
            ( "ABCDEFGH=   ", "ABCDEFGH" ),
        ]

        try tests.forEach
        {
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

            #expect( property.name == $0.name, "Data: \( $0.data )" )
        }
    }

    @Test
    func comment() async throws
    {
        let tests: [ ( data: String, comment: String? ) ] = [
            ( "FOOBAR  = 0                              ", nil ),
            ( "FOOBAR  = 0 / This is a comment          ", "This is a comment" ),
            ( "FOOBAR  = 0/ This is a comment           ", "This is a comment" ),
            ( "FOOBAR      / This is a comment          ", "This is a comment" ),
            ( "FOOBAR      /This is a comment           ", "This is a comment" ),
            ( "FOOBAR      /       This is a comment    ", "      This is a comment" ),
            ( "FOOBAR        This is a comment          ", "      This is a comment" ),
            ( "FOOBAR  =This is a comment               ", "This is a comment" ),
            ( "FOOBAR  =/ This is a comment             ", "/ This is a comment" ),
            ( "HISTORY       This is a comment          ", "      This is a comment" ),
            ( "HISTORY /     This is a comment          ", "/     This is a comment" ),
            ( "COMMENT       This is a comment          ", "      This is a comment" ),
            ( "COMMENT /     This is a comment          ", "/     This is a comment" ),
            ( "              This is a comment          ", "      This is a comment" ),
            ( "        /     This is a comment          ", "/     This is a comment" ),
        ]

        try tests.forEach
        {
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

            #expect( property.comment == $0.comment, "Data: \( $0.data )" )
        }
    }

    @Test
    func logical() async throws
    {
        let tests: [ ( data: String, value: Bool ) ] = [
            ( "FOOBAR  = T", true ),
            ( "FOOBAR  = F", false ),
        ]

        try tests.forEach
        {
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

            #expect( property.value.kind    == .logical, "Data: \( $0.data )" )
            #expect( property.value.logical != nil,      "Data: \( $0.data )" )
            #expect( property.value.logical == $0.value, "Data: \( $0.data )" )
        }
    }

    @Test
    func integer() async throws
    {
        let tests: [ ( data: String, value: Int64 ) ] = [
            ( "FOOBAR  = 0   ",   0 ),
            ( "FOOBAR  = 42  ",  42 ),
            ( "FOOBAR  = 042 ",  42 ),
            ( "FOOBAR  = +42 ",  42 ),
            ( "FOOBAR  = -42 ", -42 ),
            ( "FOOBAR  = +042",  42 ),
            ( "FOOBAR  = -042", -42 ),
        ]

        try tests.forEach
        {
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

            #expect( property.value.kind    == .integer, "Data: \( $0.data )" )
            #expect( property.value.integer != nil,      "Data: \( $0.data )" )
            #expect( property.value.integer == $0.value, "Data: \( $0.data )" )
        }
    }

    @Test
    func float() async throws
    {
        let tests: [ ( data: String, value: Double ) ] = [
            ( "FOOBAR  = 42.         ",   42.0000 ), ( "FOOBAR  = +42.         ",   42.0000 ), ( "FOOBAR  = -42.         ",   -42.0000 ),
            ( "FOOBAR  = 42.0        ",   42.0000 ), ( "FOOBAR  = +42.0        ",   42.0000 ), ( "FOOBAR  = -42.0        ",   -42.0000 ),
            ( "FOOBAR  = 42.42       ",   42.4200 ), ( "FOOBAR  = +42.42       ",   42.4200 ), ( "FOOBAR  = -42.42       ",   -42.4200 ),
            ( "FOOBAR  = .42         ",    0.4200 ), ( "FOOBAR  = +.42         ",    0.4200 ), ( "FOOBAR  = -.42         ",    -0.4200 ),
            ( "FOOBAR  =     42.     ",   42.0000 ), ( "FOOBAR  =     +42.     ",   42.0000 ), ( "FOOBAR  =     -42.     ",   -42.0000 ),
            ( "FOOBAR  =     42.0    ",   42.0000 ), ( "FOOBAR  =     +42.0    ",   42.0000 ), ( "FOOBAR  =     -42.0    ",   -42.0000 ),
            ( "FOOBAR  =     42.42   ",   42.4200 ), ( "FOOBAR  =     +42.42   ",   42.4200 ), ( "FOOBAR  =     -42.42   ",   -42.4200 ),
            ( "FOOBAR  =     .42     ",    0.4200 ), ( "FOOBAR  =     +.42     ",    0.4200 ), ( "FOOBAR  =     -.42     ",    -0.4200 ),

            ( "FOOBAR  = 42.E2       ", 4200.0000 ), ( "FOOBAR  = +42.E2       ", 4200.0000 ), ( "FOOBAR  = -42.E2       ", -4200.0000 ),
            ( "FOOBAR  = 42.0E2      ", 4200.0000 ), ( "FOOBAR  = +42.0E2      ", 4200.0000 ), ( "FOOBAR  = -42.0E2      ", -4200.0000 ),
            ( "FOOBAR  = 42.42E2     ", 4242.0000 ), ( "FOOBAR  = +42.42E2     ", 4242.0000 ), ( "FOOBAR  = -42.42E2     ", -4242.0000 ),
            ( "FOOBAR  = .42E2       ",   42.0000 ), ( "FOOBAR  = +.42E2       ",   42.0000 ), ( "FOOBAR  = -.42E2       ",   -42.0000 ),
            ( "FOOBAR  =     42.E2   ", 4200.0000 ), ( "FOOBAR  =     +42.E2   ", 4200.0000 ), ( "FOOBAR  =     -42.E2   ", -4200.0000 ),
            ( "FOOBAR  =     42.0E2  ", 4200.0000 ), ( "FOOBAR  =     +42.0E2  ", 4200.0000 ), ( "FOOBAR  =     -42.0E2  ", -4200.0000 ),
            ( "FOOBAR  =     42.42E2 ", 4242.0000 ), ( "FOOBAR  =     +42.42E2 ", 4242.0000 ), ( "FOOBAR  =     -42.42E2 ", -4242.0000 ),
            ( "FOOBAR  =     .42E2   ",   42.0000 ), ( "FOOBAR  =     +.42E2   ",   42.0000 ), ( "FOOBAR  =     -.42E2   ",   -42.0000 ),

            ( "FOOBAR  = 42.E+2      ", 4200.0000 ), ( "FOOBAR  = +42.E+2      ", 4200.0000 ), ( "FOOBAR  = -42.E+2      ", -4200.0000 ),
            ( "FOOBAR  = 42.0E+2     ", 4200.0000 ), ( "FOOBAR  = +42.0E+2     ", 4200.0000 ), ( "FOOBAR  = -42.0E+2     ", -4200.0000 ),
            ( "FOOBAR  = 42.42E+2    ", 4242.0000 ), ( "FOOBAR  = +42.42E+2    ", 4242.0000 ), ( "FOOBAR  = -42.42E+2    ", -4242.0000 ),
            ( "FOOBAR  = .42E+2      ",   42.0000 ), ( "FOOBAR  = +.42E+2      ",   42.0000 ), ( "FOOBAR  = -.42E+2      ",   -42.0000 ),
            ( "FOOBAR  =     42.E+2  ", 4200.0000 ), ( "FOOBAR  =     +42.E+2  ", 4200.0000 ), ( "FOOBAR  =     -42.E+2  ", -4200.0000 ),
            ( "FOOBAR  =     42.0E+2 ", 4200.0000 ), ( "FOOBAR  =     +42.0E+2 ", 4200.0000 ), ( "FOOBAR  =     -42.0E+2 ", -4200.0000 ),
            ( "FOOBAR  =     42.42E+2", 4242.0000 ), ( "FOOBAR  =     +42.42E+2", 4242.0000 ), ( "FOOBAR  =     -42.42E+2", -4242.0000 ),
            ( "FOOBAR  =     .42E+2  ",   42.0000 ), ( "FOOBAR  =     +.42E+2  ",   42.0000 ), ( "FOOBAR  =     -.42E+2  ",   -42.0000 ),

            ( "FOOBAR  = 42.E-2      ",    0.4200 ), ( "FOOBAR  = +42.E-2      ",    0.4200 ), ( "FOOBAR  = -42.E-2      ",    -0.4200 ),
            ( "FOOBAR  = 42.0E-2     ",    0.4200 ), ( "FOOBAR  = +42.0E-2     ",    0.4200 ), ( "FOOBAR  = -42.0E-2     ",    -0.4200 ),
            ( "FOOBAR  = 42.42E-2    ",    0.4242 ), ( "FOOBAR  = +42.42E-2    ",    0.4242 ), ( "FOOBAR  = -42.42E-2    ",    -0.4242 ),
            ( "FOOBAR  = .42E-2      ",    0.0042 ), ( "FOOBAR  = +.42E-2      ",    0.0042 ), ( "FOOBAR  = -.42E-2      ",    -0.0042 ),
            ( "FOOBAR  =     42.E-2  ",    0.4200 ), ( "FOOBAR  =     +42.E-2  ",    0.4200 ), ( "FOOBAR  =     -42.E-2  ",    -0.4200 ),
            ( "FOOBAR  =     42.0E-2 ",    0.4200 ), ( "FOOBAR  =     +42.0E-2 ",    0.4200 ), ( "FOOBAR  =     -42.0E-2 ",    -0.4200 ),
            ( "FOOBAR  =     42.42E-2",    0.4242 ), ( "FOOBAR  =     +42.42E-2",    0.4242 ), ( "FOOBAR  =     -42.42E-2",    -0.4242 ),
            ( "FOOBAR  =     .42E-2  ",    0.0042 ), ( "FOOBAR  =     +.42E-2  ",    0.0042 ), ( "FOOBAR  =     -.42E-2  ",    -0.0042 ),

            ( "FOOBAR  = 42.D2       ", 4200.0000 ), ( "FOOBAR  = +42.D2       ", 4200.0000 ), ( "FOOBAR  = -42.D2       ", -4200.0000 ),
            ( "FOOBAR  = 42.0D2      ", 4200.0000 ), ( "FOOBAR  = +42.0D2      ", 4200.0000 ), ( "FOOBAR  = -42.0D2      ", -4200.0000 ),
            ( "FOOBAR  = 42.42D2     ", 4242.0000 ), ( "FOOBAR  = +42.42D2     ", 4242.0000 ), ( "FOOBAR  = -42.42D2     ", -4242.0000 ),
            ( "FOOBAR  = .42D2       ",   42.0000 ), ( "FOOBAR  = +.42D2       ",   42.0000 ), ( "FOOBAR  = -.42D2       ",   -42.0000 ),
            ( "FOOBAR  =     42.D2   ", 4200.0000 ), ( "FOOBAR  =     +42.D2   ", 4200.0000 ), ( "FOOBAR  =     -42.D2   ", -4200.0000 ),
            ( "FOOBAR  =     42.0D2  ", 4200.0000 ), ( "FOOBAR  =     +42.0D2  ", 4200.0000 ), ( "FOOBAR  =     -42.0D2  ", -4200.0000 ),
            ( "FOOBAR  =     42.42D2 ", 4242.0000 ), ( "FOOBAR  =     +42.42D2 ", 4242.0000 ), ( "FOOBAR  =     -42.42D2 ", -4242.0000 ),
            ( "FOOBAR  =     .42D2   ",   42.0000 ), ( "FOOBAR  =     +.42D2   ",   42.0000 ), ( "FOOBAR  =     -.42D2   ",   -42.0000 ),

            ( "FOOBAR  = 42.D+2      ", 4200.0000 ), ( "FOOBAR  = +42.D+2      ", 4200.0000 ), ( "FOOBAR  = -42.D+2      ", -4200.0000 ),
            ( "FOOBAR  = 42.0D+2     ", 4200.0000 ), ( "FOOBAR  = +42.0D+2     ", 4200.0000 ), ( "FOOBAR  = -42.0D+2     ", -4200.0000 ),
            ( "FOOBAR  = 42.42D+2    ", 4242.0000 ), ( "FOOBAR  = +42.42D+2    ", 4242.0000 ), ( "FOOBAR  = -42.42D+2    ", -4242.0000 ),
            ( "FOOBAR  = .42D+2      ",   42.0000 ), ( "FOOBAR  = +.42D+2      ",   42.0000 ), ( "FOOBAR  = -.42D+2      ",   -42.0000 ),
            ( "FOOBAR  =     42.D+2  ", 4200.0000 ), ( "FOOBAR  =     +42.D+2  ", 4200.0000 ), ( "FOOBAR  =     -42.D+2  ", -4200.0000 ),
            ( "FOOBAR  =     42.0D+2 ", 4200.0000 ), ( "FOOBAR  =     +42.0D+2 ", 4200.0000 ), ( "FOOBAR  =     -42.0D+2 ", -4200.0000 ),
            ( "FOOBAR  =     42.42D+2", 4242.0000 ), ( "FOOBAR  =     +42.42D+2", 4242.0000 ), ( "FOOBAR  =     -42.42D+2", -4242.0000 ),
            ( "FOOBAR  =     .42D+2  ",   42.0000 ), ( "FOOBAR  =     +.42D+2  ",   42.0000 ), ( "FOOBAR  =     -.42D+2  ",   -42.0000 ),

            ( "FOOBAR  = 42.D-2      ",    0.4200 ), ( "FOOBAR  = +42.D-2      ",    0.4200 ), ( "FOOBAR  = -42.D-2      ",    -0.4200 ),
            ( "FOOBAR  = 42.0D-2     ",    0.4200 ), ( "FOOBAR  = +42.0D-2     ",    0.4200 ), ( "FOOBAR  = -42.0D-2     ",    -0.4200 ),
            ( "FOOBAR  = 42.42D-2    ",    0.4242 ), ( "FOOBAR  = +42.42D-2    ",    0.4242 ), ( "FOOBAR  = -42.42D-2    ",    -0.4242 ),
            ( "FOOBAR  = .42D-2      ",    0.0042 ), ( "FOOBAR  = +.42D-2      ",    0.0042 ), ( "FOOBAR  = -.42D-2      ",    -0.0042 ),
            ( "FOOBAR  =     42.D-2  ",    0.4200 ), ( "FOOBAR  =     +42.D-2  ",    0.4200 ), ( "FOOBAR  =     -42.D-2  ",    -0.4200 ),
            ( "FOOBAR  =     42.0D-2 ",    0.4200 ), ( "FOOBAR  =     +42.0D-2 ",    0.4200 ), ( "FOOBAR  =     -42.0D-2 ",    -0.4200 ),
            ( "FOOBAR  =     42.42D-2",    0.4242 ), ( "FOOBAR  =     +42.42D-2",    0.4242 ), ( "FOOBAR  =     -42.42D-2",    -0.4242 ),
            ( "FOOBAR  =     .42D-2  ",    0.0042 ), ( "FOOBAR  =     +.42D-2  ",    0.0042 ), ( "FOOBAR  =     -.42D-2  ",    -0.0042 ),
        ]

        try tests.forEach
        {
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

            #expect( property.value.kind  == .float,   "Data: \( $0.data )" )
            #expect( property.value.float != nil,      "Data: \( $0.data )" )
            #expect( property.value.float == $0.value, "Data: \( $0.data )" )
        }
    }

    @Test
    func lowercaseExponentIsUnknownWhenStrict() async throws
    {
        // FITS 4.0 fixes the exponent marker as uppercase E or D. Strict parsing
        // keeps lowercase e/d out of the float grammar, so such a value is
        // preserved verbatim as .unknown rather than recovered as a float.
        let tests = [ "1.5e3", "1.5d3", "+.42e-2", "-42.0d+2" ]

        try tests.forEach
        {
            let property = try FITSProperty( string: "FOOBAR  = \( $0 )".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .strict )

            #expect( property.value.kind == .unknown,         "Data: \( $0 )" )
            #expect( property.value      == .unknown( $0 ),   "Data: \( $0 )" )
        }
    }

    @Test
    func lowercaseExponentIsFloatWhenLenient() async throws
    {
        // allowLowercaseExponents (folded into .lenient) admits lowercase e/d
        // into the exponent grammar; Double then parses the value once the
        // marker is normalized.
        let tests: [ ( data: String, value: Double ) ] = [
            ( "1.5e3",    1500.0 ),
            ( "1.5d3",    1500.0 ),
            ( "+.42e-2",  0.0042 ),
            ( "-42.0d+2", -4200.0 ),
        ]

        try tests.forEach
        {
            let property = try FITSProperty( string: "FOOBAR  = \( $0.data )".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

            #expect( property.value.kind  == .float,    "Data: \( $0.data )" )
            #expect( property.value.float == $0.value,  "Data: \( $0.data )" )
        }
    }

    @Test
    func uppercaseExponentIsFloatInBothModes() async throws
    {
        // Regression guard: the uppercase E/D grammar is unchanged by the
        // lowercase leniency and still classifies as a float in either mode.
        let tests: [ ( data: String, value: Double ) ] = [
            ( "1.5E3", 1500.0 ),
            ( "1.5D3", 1500.0 ),
        ]

        try tests.forEach
        {
            let strict  = try FITSProperty( string: "FOOBAR  = \( $0.data )".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .strict )
            let lenient = try FITSProperty( string: "FOOBAR  = \( $0.data )".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

            #expect( strict.value.kind   == .float,   "Data: \( $0.data )" )
            #expect( strict.value.float  == $0.value, "Data: \( $0.data )" )
            #expect( lenient.value.kind  == .float,   "Data: \( $0.data )" )
            #expect( lenient.value.float == $0.value, "Data: \( $0.data )" )
        }
    }

    @Test
    func unknownValueIsTrimmedConsistentlyWithNumericCases() async throws
    {
        // A commented value field is split at "/", so the literal handed to the
        // classifier keeps the space that preceded the slash. The .unknown
        // branches must trim that padding just like the numeric branches do,
        // rather than preserving the raw, space-padded literal.
        let tests = [
            "bad",                    // matches no grammar
            "99999999999999999999",   // matches integer grammar but overflows Int64
            "1E400",                  // matches float grammar but overflows Double
        ]

        try tests.forEach
        {
            let property = try FITSProperty( string: "FOOBAR  = \( $0 ) / comment".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

            #expect( property.value.kind == .unknown,       "Data: \( $0 )" )
            #expect( property.value      == .unknown( $0 ),  "Data: \( $0 )" )
        }
    }

    @Test
    func stringAndNonStringValueCommentsNormalizeIdentically() async throws
    {
        // The same comment text with the same surrounding spaces must normalize
        // identically whether it follows a string value or a non-string value:
        // the single space conventionally following "/" is dropped, the rest is
        // preserved.
        let stringValue  = try FITSProperty( string: "FOOBAR  = 'hi' /  spaced".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )
        let integerValue = try FITSProperty( string: "FOOBAR  = 1 /  spaced".padding(    toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

        #expect( stringValue.value.kind  == .string )
        #expect( integerValue.value.kind == .integer )
        #expect( stringValue.comment  == integerValue.comment )
        #expect( stringValue.comment  == " spaced" )
        #expect( integerValue.comment == " spaced" )
    }

    @Test
    func string() async throws
    {
        let tests: [ ( data: String, value: String ) ] = [
            ( "FOOBAR  = 'hello, world'        ", "hello, world" ),
            ( "FOOBAR  = 'hello, world '       ", "hello, world" ),
            ( "FOOBAR  = '    hello, world'    ", "    hello, world" ),
            ( "FOOBAR  = '    hello, world    '", "    hello, world" ),
            ( "FOOBAR  = ''                    ", "" ),
            ( "FOOBAR  = ' '                   ", " " ),
            ( "FOOBAR  = '    '                ", " " ),
        ]

        try tests.forEach
        {
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

            #expect( property.value.kind   == .string,  "Data: \( $0.data )" )
            #expect( property.value.string != nil,      "Data: \( $0.data )" )
            #expect( property.value.string == $0.value, "Data: \( $0.data )" )
        }

        #expect( throws: FITSError.self ) { try FITSProperty( string: "FOOBAR  = 'hello, world".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient ) }
    }

    @Test
    func stringWithJunkAfterClosingQuoteIsRejectedWhenStrict() async throws
    {
        // In strict mode, non-blank characters between the closing quote and the
        // comment delimiter (or end of record) must be rejected, not dropped.
        #expect( throws: FITSError.self ) { try FITSProperty( string: "FOOBAR  = 'hi' junk / comment".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .strict ) }
        #expect( throws: FITSError.self ) { try FITSProperty( string: "FOOBAR  = 'hi' junk".padding(           toLength: 80, withPad: " ", startingAt: 0 ), options: .strict ) }

        // A blank gap before the delimiter remains valid in strict mode.
        let property = try FITSProperty( string: "FOOBAR  = 'hi'   / comment".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .strict )

        #expect( property.value.string == "hi" )
        #expect( property.comment      == "comment" )
    }

    @Test
    func stringWithJunkAfterClosingQuoteIsToleratedWhenNonStrict() async throws
    {
        // In non-strict mode the noncompliant trailing characters are dropped
        // and the value/comment are still recovered.
        let p1 = try FITSProperty( string: "FOOBAR  = 'hi' junk / comment".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

        #expect( p1.value.string == "hi" )
        #expect( p1.comment      == "comment" )

        let p2 = try FITSProperty( string: "FOOBAR  = 'hi' junk".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

        #expect( p2.value.string == "hi" )
        #expect( p2.comment      == nil )
    }

    @Test
    func undefined() async throws
    {
        let tests: [ ( data: String, comment: String? ) ] = [
            ( "FOOBAR  =                    ", nil ),
            ( "FOOBAR  =/ This is a comment ", "/ This is a comment" ),
            ( "FOOBAR  = / This is a comment", "This is a comment" ),
        ]

        try tests.forEach
        {
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

            #expect( property.value.kind == .undefined, "Data: \( $0.data )" )
            #expect( property.value      == .undefined, "Data: \( $0.data )" )
            #expect( property.comment    == $0.comment, "Data: \( $0.data )" )
        }
    }

    @Test
    func unknown() async throws
    {
        // The .unknown literal is trimmed of its surrounding field padding,
        // consistent with the numeric cases, regardless of the spacing around
        // the value or the slash that ends it.
        let tests: [ ( data: String, value: String, comment: String? ) ] = [
            ( "FOOBAR  = a",                      "a", nil ),
            ( "FOOBAR  = a / This is a comment",  "a", "This is a comment" ),
            ( "FOOBAR  = a/ This is a comment",   "a", "This is a comment" ),
            ( "FOOBAR  =  a",                     "a", nil ),
            ( "FOOBAR  =  a / This is a comment", "a", "This is a comment" ),
            ( "FOOBAR  =  a/ This is a comment",  "a", "This is a comment" ),
        ]

        try tests.forEach
        {
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

            #expect( property.value.kind == .unknown,             "Data: \( $0.data )" )
            #expect( property.value      == .unknown( $0.value ), "Data: \( $0.data )" )
            #expect( property.comment    == $0.comment,           "Data: \( $0.data )" )
        }
    }

    @Test
    func integerOverflowingInt64IsUnknownNotFloat() async throws
    {
        // A literal that matches the integer grammar but overflows Int64 must
        // keep its exact text as .unknown, not be silently reinterpreted as a
        // lossy float.
        let positive = try FITSProperty( string: "FOOBAR  = 12345678901234567890".padding(  toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )
        let negative = try FITSProperty( string: "FOOBAR  = -12345678901234567890".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

        #expect( positive.value == .unknown( "12345678901234567890" ) )
        #expect( negative.value == .unknown( "-12345678901234567890" ) )
    }

    @Test
    func floatOverflowingDoubleIsUnknownNotInfinity() async throws
    {
        // A literal that matches the float grammar but overflows Double (to
        // ±inf) must keep its exact text as .unknown, not become
        // .float(.infinity), so callers can tell an unrepresentable value from
        // a genuine infinity. A large-but-finite value still parses as a float.
        let positive = try FITSProperty( string: "FOOBAR  = 1E400".padding(  toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )
        let negative = try FITSProperty( string: "FOOBAR  = -1E400".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )
        let finite   = try FITSProperty( string: "FOOBAR  = 1E300".padding(  toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

        #expect( positive.value == .unknown( "1E400" ) )
        #expect( negative.value == .unknown( "-1E400" ) )
        #expect( finite.value   == .float( 1e300 ) )
    }

    @Test
    func nulPaddedValueIsHonoredWithFlag() async throws
    {
        // A value field padded/terminated with NUL bytes (FOO = T\0\0\0).
        // allowNulPaddingInValues extends NUL-aware trimming to the value field,
        // so the value classifies as a logical rather than .unknown.
        let record = ( "FOO     = T" + "\u{0}\u{0}\u{0}" ).padding( toLength: 80, withPad: " ", startingAt: 0 )

        let withFlag    = try FITSProperty( string: record, options: [ .strict, .allowNulPaddingInValues ] )
        let withoutFlag = try FITSProperty( string: record, options: .strict )

        #expect( withFlag.value         == .logical( true ) )
        #expect( withoutFlag.value.kind == .unknown )
    }

    @Test
    func nulPaddedCommentIsTrimmedWithFlag() async throws
    {
        // A COMMENT record terminated with NUL bytes. With the flag the trailing
        // NULs are trimmed from the comment; without it they are preserved.
        let record = ( "COMMENT Hello" + "\u{0}\u{0}" ).padding( toLength: 80, withPad: " ", startingAt: 0 )

        let withFlag    = try FITSProperty( string: record, options: [ .strict, .allowNulPaddingInValues ] )
        let withoutFlag = try FITSProperty( string: record, options: .strict )

        #expect( withFlag.comment    == "Hello" )
        #expect( withoutFlag.comment == "Hello\u{0}\u{0}" )
    }

    @Test
    func missingValueIndicatorSpaceIsRejectedWhenStrict() async throws
    {
        // "FOOBAR  =T" has "=" in column 9 but no space in column 10, so the
        // value indicator is malformed. Strict parsing must reject it instead of
        // silently turning the intended value into a comment.
        let record = "FOOBAR  =T".padding( toLength: 80, withPad: " ", startingAt: 0 )

        #expect( throws: FITSError.self ) { try FITSProperty( string: record, options: .strict ) }
    }

    @Test
    func missingValueIndicatorSpaceIsToleratedWhenLenient() async throws
    {
        let record   = "FOOBAR  =T".padding( toLength: 80, withPad: " ", startingAt: 0 )
        let property = try FITSProperty( string: record, options: .lenient )

        #expect( property.value.kind == .undefined )
        #expect( property.comment    == "T" )
    }

    @Test
    func commentOnlyRecordIsUnaffectedByValueIndicatorCheck() async throws
    {
        // A genuine comment-only record and an empty value must still parse
        // cleanly in strict mode — only a present-but-spaceless "=" is rejected.
        let commentOnly = "FOOBAR  = / This is a comment".padding( toLength: 80, withPad: " ", startingAt: 0 )
        let emptyValue  = "FOOBAR  = ".padding( toLength: 80, withPad: " ", startingAt: 0 )

        let p1 = try FITSProperty( string: commentOnly, options: .strict )
        let p2 = try FITSProperty( string: emptyValue,  options: .strict )

        #expect( p1.value.kind == .undefined )
        #expect( p1.comment    == "This is a comment" )
        #expect( p2.value.kind == .undefined )
    }

    @Test
    func mergeHistory() async throws
    {
        let p1 = try FITSProperty( string: "HISTORY hello".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )
        let p2 = try FITSProperty( string: "HISTORY world".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

        #expect( p1.comment == "hello" )
        #expect( p2.comment == "world" )

        try p1.merge( with: p2 )

        #expect( p1.comment == "hello\nworld" )
        #expect( p2.comment == "world" )
    }

    @Test
    func mergeHistoryFail() async throws
    {
        let p1 = try FITSProperty( string: "SIMPLE  = T  ".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )
        let p2 = try FITSProperty( string: "HISTORY world".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

        #expect( throws: FITSError.self ) { try p1.merge( with: p2 ) }
        #expect( throws: FITSError.self ) { try p2.merge( with: p1 ) }
    }

    @Test
    func mergeComment() async throws
    {
        let p1 = try FITSProperty( string: "COMMENT hello".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )
        let p2 = try FITSProperty( string: "COMMENT world".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

        #expect( p1.comment == "hello" )
        #expect( p2.comment == "world" )

        try p1.merge( with: p2 )

        #expect( p1.comment == "hello\nworld" )
        #expect( p2.comment == "world" )
    }

    @Test
    func mergeCommentFail() async throws
    {
        let p1 = try FITSProperty( string: "SIMPLE  = T  ".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )
        let p2 = try FITSProperty( string: "COMMENT world".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

        #expect( throws: FITSError.self ) { try p1.merge( with: p2 ) }
        #expect( throws: FITSError.self ) { try p2.merge( with: p1 ) }
    }

    @Test
    func mergeString() async throws
    {
        let p1 = try FITSProperty( string: "FOOBAR  = 'hello&' / This is".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )
        let p2 = try FITSProperty( string: "CONTINUE  ', &   ' / a      ".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )
        let p3 = try FITSProperty( string: "CONTINUE  'world ' / comment".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

        #expect( p1.value.kind == .string )
        #expect( p2.value.kind == .string )
        #expect( p3.value.kind == .string )

        #expect( p1.value.string == "hello&" )
        #expect( p2.value.string == ", &" )
        #expect( p3.value.string == "world" )

        #expect( p1.comment == "This is" )
        #expect( p2.comment == "a" )
        #expect( p3.comment == "comment" )

        try p1.merge( with: p2 )
        try p1.merge( with: p3 )

        #expect( p1.value.string == "hello, world" )
        #expect( p2.value.string == ", &" )
        #expect( p3.value.string == "world" )

        #expect( p1.comment == "This is\na\ncomment" )
        #expect( p2.comment == "a" )
        #expect( p3.comment == "comment" )
    }

    @Test
    func mergeStringFail() async throws
    {
        let p1 = try FITSProperty( string: "FOOBAR  = 'hello&' ".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )
        let p2 = try FITSProperty( string: "FOOBAR  = 'hello'  ".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )
        let p3 = try FITSProperty( string: "CONTINUE  ', world'".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

        #expect( p1.value.kind == .string )
        #expect( p2.value.kind == .string )
        #expect( p3.value.kind == .string )

        #expect( p1.value.string == "hello&" )
        #expect( p2.value.string == "hello" )
        #expect( p3.value.string == ", world" )

        #expect( throws: FITSError.self ) { try p1.merge( with: p2 ) }
        #expect( throws: FITSError.self ) { try p2.merge( with: p3 ) }
    }

    @Test
    func valuelessRecordHasNilComment() async throws
    {
        // A keyword with neither a value nor a comment must yield comment == nil,
        // consistent with the value-less "= " path, not an empty string.
        let property = try FITSProperty( string: "FOOBAR".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

        #expect( property.value.kind == .undefined )
        #expect( property.comment    == nil )
    }

    @Test
    func mergeHistoryWithNilLeftCommentHasNoLeadingNewline() async throws
    {
        let p1 = try FITSProperty( string: "HISTORY".padding(       toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )
        let p2 = try FITSProperty( string: "HISTORY world".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

        #expect( p1.comment == nil )
        #expect( p2.comment == "world" )

        try p1.merge( with: p2 )

        #expect( p1.comment == "world" )
    }

    @Test
    func mergeStringWithNilRightCommentHasNoTrailingNewline() async throws
    {
        let p1 = try FITSProperty( string: "FOOBAR  = 'hello&' / This is".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )
        let p2 = try FITSProperty( string: "CONTINUE  'world '".padding(          toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

        #expect( p1.comment == "This is" )
        #expect( p2.comment == nil )

        try p1.merge( with: p2 )

        #expect( p1.value.string == "helloworld" )
        #expect( p1.comment          == "This is" )
    }

    @Test
    func description() async throws
    {
        let tests: [ ( field: String, contains: [ String ] ) ] = [
            ( "FOOBAR  = T       / This is a comment", [ "FOOBAR", "Logical",   "true",  "This is a comment" ] ),
            ( "FOOBAR  = 42      / This is a comment", [ "FOOBAR", "Integer",   "42",    "This is a comment" ] ),
            ( "FOOBAR  = 42.42   / This is a comment", [ "FOOBAR", "Float",     "42.42", "This is a comment" ] ),
            ( "FOOBAR  = 'hello' / This is a comment", [ "FOOBAR", "String",    "hello", "This is a comment" ] ),
            ( "FOOBAR  =         / This is a comment", [ "FOOBAR", "Undefined",          "This is a comment" ] ),
            ( "FOOBAR  = xyz     / This is a comment", [ "FOOBAR", "Unknown",   "xyz",   "This is a comment" ] ),
        ]

        try tests.forEach
        {
            test in

            let property = try FITSProperty( string: test.field.padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

            #expect( property.description.isEmpty == false )
            #expect( property.description         != _typeName( FITSProperty.self, qualified: true ) )

            test.contains.forEach
            {
                #expect( property.description.contains( $0 ), "Data: \( test.field )" )
            }
        }
    }

    @Test
    func invalidContinue() async throws
    {
        #expect( throws: FITSError.self ) { try FITSProperty( string: "CONTINUE=   ".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient ) }
        #expect( throws: FITSError.self ) { try FITSProperty( string: "CONTINUE='' ".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient ) }
        #expect( throws: FITSError.self ) { try FITSProperty( string: "CONTINUE= ''".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient ) }
        #expect( throws: FITSError.self ) { try FITSProperty( string: "CONTINUE=  0".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient ) }
    }

    @Test
    func quotesInString() async throws
    {
        let property = try FITSProperty( string: "FOOBAR  = '''hello''world'''".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

        #expect( property.value.kind   == .string )
        #expect( property.value.string != nil )
        #expect( property.value.string == "'hello'world'" )
    }

    @Test
    func normalizesKeyword() async throws
    {
        // Valid names (including the blank commentary keyword) pass through.
        #expect( try FITSProperty.normalizedKeyword( "SIMPLE", options: .strict ) == "SIMPLE" )
        #expect( try FITSProperty.normalizedKeyword( "NAXIS1", options: .strict ) == "NAXIS1" )
        #expect( try FITSProperty.normalizedKeyword( "", options: .strict )       == "" )

        // Strict rejects an out-of-charset name; lenient upper-cases it.
        #expect( throws: FITSError.self ) { try FITSProperty.normalizedKeyword( "foo", options: .strict ) }
        #expect( try FITSProperty.normalizedKeyword( "foo", options: .lenient ) == "FOO" )

        // A name that cannot be coerced into the charset still throws under lenient.
        #expect( throws: FITSError.self ) { try FITSProperty.normalizedKeyword( "foo bar", options: .lenient ) }

        // A name longer than the keyword field can never fit, in either mode.
        #expect( throws: FITSError.self ) { try FITSProperty.normalizedKeyword( "TOOLONGNAME", options: .strict ) }
        #expect( throws: FITSError.self ) { try FITSProperty.normalizedKeyword( "TOOLONGNAME", options: .lenient ) }
    }

    @Test
    func fixedFormatCardsAreIdempotent() async throws
    {
        // Each card is already in the library's canonical fixed-format layout,
        // so parsing then re-serializing must reproduce it byte-for-byte.
        let cards =
            [
                Test_FITSProperty.pad80( "SIMPLE  = " + Test_FITSProperty.rightJustified( "T" )   + " / Standard FITS format" ),
                Test_FITSProperty.pad80( "BITPIX  = " + Test_FITSProperty.rightJustified( "-32" ) + " / 32 bit" ),
                Test_FITSProperty.pad80( "NAXIS   = " + Test_FITSProperty.rightJustified( "2" ) ),
                Test_FITSProperty.pad80( "SOMEFLT = " + Test_FITSProperty.rightJustified( "1.5" ) + " / a float" ),
                Test_FITSProperty.pad80( "OBJECT  = 'M42'" ),
                Test_FITSProperty.pad80( "OBJECT  = 'M42' / the observed object" ),
                Test_FITSProperty.pad80( "COMMENT   FITS is a data format" ),
                Test_FITSProperty.pad80( "HISTORY processed on 2026-07-11" ),
            ]

        try cards.forEach
        {
            card in

            let property = try FITSProperty( string: card, options: .strict )

            #expect( try property.serialized( options: .strict ) == [ card ], "Not idempotent: \( card )" )
        }
    }

    @Test
    func serializesLogicalRightJustifiedToColumn30() async throws
    {
        let property = try FITSProperty( string: Test_FITSProperty.pad80( "SIMPLE  = " + Test_FITSProperty.rightJustified( "T" ) ), options: .strict )
        let cards    = try property.serialized( options: .strict )

        try #require( cards.count == 1 )
        try #require( cards[ 0 ].count == FITSFile.cardSize )

        // The logical value must land in byte 30 (index 29).
        let scalars = Array( cards[ 0 ] )

        #expect( scalars[ 29 ] == "T" )
        #expect( scalars[ 28 ] == " " )
    }

    @Test
    func serializesXtensionValuePaddedToEight() async throws
    {
        let property = try FITSProperty( string: Test_FITSProperty.pad80( "XTENSION= 'IMAGE   '" ), options: .strict )
        let cards    = try property.serialized( options: .strict )

        #expect( cards == [ Test_FITSProperty.pad80( "XTENSION= 'IMAGE   '" ) ] )
    }

    @Test
    func serializesMergedCommentaryAsOneCardPerLine() async throws
    {
        let property = try FITSProperty( string: Test_FITSProperty.pad80( "COMMENT line one" ), options: .strict )

        try property.merge( with: FITSProperty( string: Test_FITSProperty.pad80( "COMMENT line two" ), options: .strict ) )

        let cards = try property.serialized( options: .strict )

        #expect( cards == [ Test_FITSProperty.pad80( "COMMENT line one" ), Test_FITSProperty.pad80( "COMMENT line two" ) ] )
    }

    @Test
    func serializesLongStringAsContinuedRecords() async throws
    {
        // Build a 110-character string value by parsing and merging, then verify
        // it re-serializes into multiple CONTINUE records that re-parse equal.
        let head     = String( repeating: "A", count: 60 )
        let tail     = String( repeating: "B", count: 50 )
        let property = try FITSProperty( string: Test_FITSProperty.pad80( "LONGSTR = '\( head )&'" ), options: .strict )

        try property.merge( with: FITSProperty( string: Test_FITSProperty.pad80( "CONTINUE  '\( tail )'" ), options: .strict ) )

        let cards = try property.serialized( options: .strict )

        try #require( cards.count >= 2 )

        cards.forEach { #expect( $0.count == FITSFile.cardSize ) }

        #expect( cards[ 0 ].hasPrefix( "LONGSTR = " ) )
        #expect( cards.dropFirst().allSatisfy { $0.hasPrefix( "CONTINUE  " ) } )

        let reparsed = try FITSProperty( string: cards[ 0 ], options: .strict )

        try cards.dropFirst().forEach { try reparsed.merge( with: FITSProperty( string: $0, options: .strict ) ) }

        #expect( reparsed.value == property.value )
        #expect( reparsed.value.string == head + tail )
    }

    @Test
    func serializesLongStringWithCommentSpillingToOwnCard() async throws
    {
        // A 132-character value splits into two full ~67-char pieces, so the
        // comment cannot fit on the last value card and must trail on its own
        // CONTINUE record. Both the value and the comment must round-trip.
        let head     = String( repeating: "A", count: 66 )
        let tail     = String( repeating: "B", count: 66 )
        let property = try FITSProperty( string: Test_FITSProperty.pad80( "LONGSTR = '\( head )&'" ), options: .strict )

        try property.merge( with: FITSProperty( string: Test_FITSProperty.pad80( "CONTINUE  '\( tail )&'" ), options: .strict ) )
        try property.merge( with: FITSProperty( string: Test_FITSProperty.pad80( "CONTINUE  '' / a trailing note" ), options: .strict ) )

        try #require( property.value.string == head + tail )
        try #require( property.comment      == "a trailing note" )

        let cards = try property.serialized( options: .strict )

        cards.forEach { #expect( $0.count == FITSFile.cardSize ) }

        let reparsed = try FITSProperty( string: cards[ 0 ], options: .strict )

        try cards.dropFirst().forEach { try reparsed.merge( with: FITSProperty( string: $0, options: .strict ) ) }

        #expect( reparsed.value.string == head + tail )
        #expect( reparsed.comment      == "a trailing note" )
    }

    @Test
    func serializesLongStringWithQuotesAndAmpersands() async throws
    {
        // A long value carrying an interior single quote and an ampersand near a
        // chunk boundary must survive escaping and the "&" continuation flag.
        let head     = String( repeating: "A", count: 55 )
        let tail     = String( repeating: "B", count: 55 )
        let expected = head + "'" + "&" + tail
        let property = try FITSProperty( string: Test_FITSProperty.pad80( "QANDA   = '\( head )''&&'" ), options: .strict )

        try property.merge( with: FITSProperty( string: Test_FITSProperty.pad80( "CONTINUE  '\( tail )'" ), options: .strict ) )

        try #require( property.value.string == expected )

        let cards    = try property.serialized( options: .strict )
        let reparsed = try FITSProperty( string: cards[ 0 ], options: .strict )

        try cards.dropFirst().forEach { try reparsed.merge( with: FITSProperty( string: $0, options: .strict ) ) }

        #expect( reparsed.value.string == expected )
    }

    @Test
    func serializesLongScalarInFreeFormat() async throws
    {
        // A value literal longer than the 20-char fixed field is placed starting
        // at byte 11 (free-format) rather than right-justified.
        let property = try FITSProperty( string: Test_FITSProperty.pad80( "BIGFLOAT= 1.7976931348623157E+308" ), options: .strict )

        try #require( property.value.kind == .float )

        let cards = try property.serialized( options: .strict )

        try #require( cards.count == 1 )

        let scalars = Array( cards[ 0 ] )

        #expect( cards[ 0 ].count == FITSFile.cardSize )
        #expect( scalars[ 10 ] != " " )

        let reparsed = try FITSProperty( string: cards[ 0 ], options: .strict )

        #expect( reparsed.value == property.value )
    }

    @Test
    func serializesNullAndEmptyStrings() async throws
    {
        // The null string ('') and the empty string (' ') keep their distinct
        // representations through serialization.
        let null  = try FITSProperty( string: Test_FITSProperty.pad80( "NULLSTR = ''" ), options: .strict )
        let empty = try FITSProperty( string: Test_FITSProperty.pad80( "EMPTYSTR= ' '" ), options: .strict )

        try #require( null.value  == .string( "" ) )
        try #require( empty.value == .string( " " ) )

        #expect( try null.serialized(  options: .strict ) == [ Test_FITSProperty.pad80( "NULLSTR = ''" ) ] )
        #expect( try empty.serialized( options: .strict ) == [ Test_FITSProperty.pad80( "EMPTYSTR= ' '" ) ] )
    }

    @Test
    func serializesUndefinedValueKeyword() async throws
    {
        let property = try FITSProperty( string: Test_FITSProperty.pad80( "FOO     = " ), options: .strict )

        try #require( property.value.kind == .undefined )

        let cards    = try property.serialized( options: .strict )
        let reparsed = try FITSProperty( string: try #require( cards.first ), options: .strict )

        #expect( cards.count == 1 )
        #expect( reparsed.name        == "FOO" )
        #expect( reparsed.value.kind  == .undefined )
    }

    @Test
    func constructsWithDesignatedInitializer() async throws
    {
        let property = try FITSProperty( name: "OBJECT", value: .string( "M42" ), comment: "the target", options: .strict )

        #expect( property.name    == "OBJECT" )
        #expect( property.value   == .string( "M42" ) )
        #expect( property.comment == "the target" )

        // The comment defaults to nil.
        let bare = try FITSProperty( name: "NAXIS", value: .integer( 0 ), options: .strict )

        #expect( bare.comment == nil )
    }

    @Test
    func constructsWithConvenienceInitializers() async throws
    {
        let logical = try FITSProperty( name: "SIMPLE", logical: true,  options: .strict )
        let integer = try FITSProperty( name: "NAXIS",  integer: 2,     options: .strict )
        let float   = try FITSProperty( name: "BSCALE", float:   1.5,   options: .strict )
        let string  = try FITSProperty( name: "OBJECT", string:  "M42", options: .strict )

        #expect( logical.name == "SIMPLE" )
        #expect( integer.name == "NAXIS" )
        #expect( float.name   == "BSCALE" )
        #expect( string.name  == "OBJECT" )

        #expect( logical.value == .logical( true ) )
        #expect( integer.value == .integer( 2 ) )
        #expect( float.value   == .float( 1.5 ) )
        #expect( string.value  == .string( "M42" ) )

        #expect( logical.comment == nil )
        #expect( integer.comment == nil )
        #expect( float.comment   == nil )
        #expect( string.comment  == nil )
    }

    @Test
    func constructRejectsInvalidKeywordWhenStrict() async throws
    {
        // Lowercase, illegal characters and over-length names are all rejected.
        #expect( throws: FITSError.self ) { try FITSProperty( name: "foo",         value: .integer( 1 ), options: .strict ) }
        #expect( throws: FITSError.self ) { try FITSProperty( name: "FOO BAR",     value: .integer( 1 ), options: .strict ) }
        #expect( throws: FITSError.self ) { try FITSProperty( name: "TOOLONGNAME", value: .integer( 1 ), options: .strict ) }

        // Valid names, including the blank and commentary keywords, are accepted.
        #expect( throws: Never.self ) { try FITSProperty( name: "SIMPLE",  logical: true,                    options: .strict ) }
        #expect( throws: Never.self ) { try FITSProperty( name: "",        value: .undefined,                options: .strict ) }
        #expect( throws: Never.self ) { try FITSProperty( name: "COMMENT", value: .undefined, comment: "hi", options: .strict ) }
    }

    @Test
    func constructCoercesKeywordWhenLenient() async throws
    {
        // Lenient coercion upper-cases an otherwise-valid name.
        let property = try FITSProperty( name: "foo", value: .integer( 1 ), options: .lenient )

        #expect( property.name == "FOO" )

        // A name that cannot be coerced into the charset, or that overflows the
        // keyword field, still throws under lenient.
        #expect( throws: FITSError.self ) { try FITSProperty( name: "foo bar",     value: .integer( 1 ), options: .lenient ) }
        #expect( throws: FITSError.self ) { try FITSProperty( name: "toolongname", value: .integer( 1 ), options: .lenient ) }
    }

    @Test
    func valueAndCommentAreSettable() async throws
    {
        let property = try FITSProperty( name: "OBJECT", value: .string( "M42" ), comment: "first", options: .strict )

        property.value   = .integer( 7 )
        property.comment = "second"

        #expect( property.value   == .integer( 7 ) )
        #expect( property.comment == "second" )

        property.comment = nil

        #expect( property.comment == nil )
    }

    @Test
    func constructedPropertySerializesToCard() async throws
    {
        let logical = try FITSProperty( name: "SIMPLE", logical: true, comment: "Standard FITS format", options: .strict )
        let integer = try FITSProperty( name: "NAXIS",  integer: 2,                                     options: .strict )
        let float   = try FITSProperty( name: "BSCALE", float:   1.5,  comment: "a float",              options: .strict )
        let string  = try FITSProperty( name: "OBJECT", string:  "M42",                                 options: .strict )

        #expect( try logical.serialized( options: .strict ) == [ Test_FITSProperty.pad80( "SIMPLE  = " + Test_FITSProperty.rightJustified( "T" )   + " / Standard FITS format" ) ] )
        #expect( try integer.serialized( options: .strict ) == [ Test_FITSProperty.pad80( "NAXIS   = " + Test_FITSProperty.rightJustified( "2" ) ) ] )
        #expect( try float.serialized(   options: .strict ) == [ Test_FITSProperty.pad80( "BSCALE  = " + Test_FITSProperty.rightJustified( "1.5" ) + " / a float" ) ] )
        #expect( try string.serialized(  options: .strict ) == [ Test_FITSProperty.pad80( "OBJECT  = 'M42'" ) ] )
    }

    @Test
    func constructedPropertyRoundTripsThroughSerialization() async throws
    {
        let properties = [
            try FITSProperty( name: "SIMPLE", value: .logical( true ), comment: "conforms", options: .strict ),
            try FITSProperty( name: "NAXIS",  value: .integer( 2 ),    comment: nil,        options: .strict ),
            try FITSProperty( name: "BSCALE", value: .float( 1.5 ),    comment: nil,        options: .strict ),
            try FITSProperty( name: "OBJECT", value: .string( "M42" ), comment: "target",   options: .strict ),
            try FITSProperty( name: "FOO",    value: .undefined,       comment: "note",     options: .strict ),
        ]

        try properties.forEach
        {
            let cards    = try $0.serialized( options: .strict )
            let reparsed = try FITSProperty( string: try #require( cards.first ), options: .strict )

            #expect( reparsed.name    == $0.name,    "Name: \( $0.name )" )
            #expect( reparsed.value   == $0.value,   "Name: \( $0.name )" )
            #expect( reparsed.comment == $0.comment, "Name: \( $0.name )" )
        }
    }

    @Test
    func constructsNonFiniteFloatButRejectsItOnSerialization() async throws
    {
        // A non-finite float is accepted at construction (as the initializer
        // documents), and only rejected later, on serialization, since FITS has
        // no keyword-value literal for the IEEE special values.
        let values = [ Double.infinity, -Double.infinity, Double.nan ]

        try values.forEach
        {
            let property = try FITSProperty( name: "BADFLOAT", float: $0, options: .strict )

            #expect( property.value.float?.isFinite == false, "Value: \( $0 )" )
            #expect( throws: FITSError.self, "Value: \( $0 )" ) { try property.serialized( options: .strict ) }
        }
    }

    @Test
    func constructsWithUnknownValueThroughDesignatedInitializer() async throws
    {
        // The designated initializer accepts an .unknown value, which serializes
        // to its retained literal verbatim and re-parses back to the same value.
        let property = try FITSProperty( name: "WEIRD", value: .unknown( "0x1F" ), comment: "raw", options: .strict )

        #expect( property.value == .unknown( "0x1F" ) )

        let cards    = try property.serialized( options: .strict )
        let reparsed = try FITSProperty( string: try #require( cards.first ), options: .strict )

        #expect( cards.count      == 1 )
        #expect( reparsed.name    == "WEIRD" )
        #expect( reparsed.value   == .unknown( "0x1F" ) )
        #expect( reparsed.comment == "raw" )
    }

    /// Pads a record to the full card width with trailing spaces.
    ///
    /// - Parameter string: The record text, at most ``FITSFile/cardSize`` long.
    /// - Returns: The space-padded 80-character card.
    private static func pad80( _ string: String ) -> String
    {
        string.padding( toLength: FITSFile.cardSize, withPad: " ", startingAt: 0 )
    }

    /// Right-justifies a value literal within the fixed-format value field
    /// (bytes 11–30), i.e. a 20-character field.
    ///
    /// - Parameter literal: The value literal to place.
    /// - Returns: The literal padded on the left to a width of 20, or unchanged
    ///   if it is already at least that long.
    private static func rightJustified( _ literal: String ) -> String
    {
        literal.count >= 20 ? literal : String( repeating: " ", count: 20 - literal.count ) + literal
    }
}
