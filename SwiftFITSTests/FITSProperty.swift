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
        #expect( finite.value   == .float( 1E300 ) )
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
}
