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
        try #require( throws: FITSError.self ) { try FITSProperty( data: Data( repeating: 0xFF, count: 80 ) ) }
        try #require( throws: FITSError.self ) { try FITSProperty( data: Data( repeating: 0x20, count: 79 ) ) }
        try #require( throws: FITSError.self ) { try FITSProperty( data: Data( repeating: 0x20, count: 81 ) ) }

        let property = try FITSProperty( data: Data( repeating: 0x20, count: 80 ) )

        #expect( property.name    == "" )
        #expect( property.value   == .undefined )
        #expect( property.comment == nil )
        #expect( property.kind    == .undefined )
    }

    @Test
    func initWithString() async throws
    {
        try #require( throws: FITSError.self ) { try FITSProperty( string: String( repeating: "\u{FF}", count: 80 ) ) }
        try #require( throws: FITSError.self ) { try FITSProperty( string: String( repeating: "\u{20}", count: 79 ) ) }
        try #require( throws: FITSError.self ) { try FITSProperty( string: String( repeating: "\u{20}", count: 81 ) ) }

        let property = try FITSProperty( string: String( repeating: "\u{20}", count: 80 ) )

        #expect( property.name    == "" )
        #expect( property.value   == .undefined )
        #expect( property.comment == nil )
        #expect( property.kind    == .undefined )
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
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ) )

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
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ) )

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
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ) )

            #expect( property.kind == .logical,           "Data: \( $0.data )" )
            #expect( property.value.logical != nil,              "Data: \( $0.data )" )
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
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ) )

            #expect( property.kind == .integer,            "Data: \( $0.data )" )
            #expect( property.value.integer != nil,              "Data: \( $0.data )" )
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
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ) )

            #expect( property.kind == .float,               "Data: \( $0.data )" )
            #expect( property.value.float != nil,              "Data: \( $0.data )" )
            #expect( property.value.float == $0.value, "Data: \( $0.data )" )
        }
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
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ) )

            #expect( property.kind == .string,              "Data: \( $0.data )" )
            #expect( property.value.string != nil,              "Data: \( $0.data )" )
            #expect( property.value.string == $0.value, "Data: \( $0.data )" )
        }

        #expect( throws: FITSError.self ) { try FITSProperty( string: "FOOBAR  = 'hello, world".padding( toLength: 80, withPad: " ", startingAt: 0 ) ) }
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
        #expect( property.comment          == "comment" )
    }

    @Test
    func stringWithJunkAfterClosingQuoteIsToleratedWhenNonStrict() async throws
    {
        // In non-strict mode the noncompliant trailing characters are dropped
        // and the value/comment are still recovered.
        let p1 = try FITSProperty( string: "FOOBAR  = 'hi' junk / comment".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

        #expect( p1.value.string == "hi" )
        #expect( p1.comment          == "comment" )

        let p2 = try FITSProperty( string: "FOOBAR  = 'hi' junk".padding( toLength: 80, withPad: " ", startingAt: 0 ), options: .lenient )

        #expect( p2.value.string == "hi" )
        #expect( p2.comment          == nil )
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
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ) )

            #expect( property.kind    == .undefined, "Data: \( $0.data )" )
            #expect( property.value   == .undefined,        "Data: \( $0.data )" )
            #expect( property.comment == $0.comment, "Data: \( $0.data )" )
        }
    }

    @Test
    func unknown() async throws
    {
        let tests: [ ( data: String, value: String, comment: String? ) ] = [
            ( "FOOBAR  = a",                      "a",   nil ),
            ( "FOOBAR  = a / This is a comment",  "a ",  "This is a comment" ),
            ( "FOOBAR  = a/ This is a comment",   "a",   "This is a comment" ),
            ( "FOOBAR  =  a",                     " a",  nil ),
            ( "FOOBAR  =  a / This is a comment", " a ", "This is a comment" ),
            ( "FOOBAR  =  a/ This is a comment",  " a",  "This is a comment" ),
        ]

        try tests.forEach
        {
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ) )

            #expect( property.kind    == .unknown,             "Data: \( $0.data )" )
            #expect( property.value   == .unknown( $0.value ), "Data: \( $0.data )" )
            #expect( property.comment == $0.comment,           "Data: \( $0.data )" )
        }
    }

    @Test
    func mergeHistory() async throws
    {
        let p1 = try FITSProperty( string: "HISTORY hello".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        let p2 = try FITSProperty( string: "HISTORY world".padding( toLength: 80, withPad: " ", startingAt: 0 ) )

        #expect( p1.comment == "hello" )
        #expect( p2.comment == "world" )

        try p1.merge( with: p2 )

        #expect( p1.comment == "hello\nworld" )
        #expect( p2.comment == "world" )
    }

    @Test
    func mergeHistoryFail() async throws
    {
        let p1 = try FITSProperty( string: "SIMPLE  = T  ".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        let p2 = try FITSProperty( string: "HISTORY world".padding( toLength: 80, withPad: " ", startingAt: 0 ) )

        #expect( throws: FITSError.self ) { try p1.merge( with: p2 ) }
        #expect( throws: FITSError.self ) { try p2.merge( with: p1 ) }
    }

    @Test
    func mergeComment() async throws
    {
        let p1 = try FITSProperty( string: "COMMENT hello".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        let p2 = try FITSProperty( string: "COMMENT world".padding( toLength: 80, withPad: " ", startingAt: 0 ) )

        #expect( p1.comment == "hello" )
        #expect( p2.comment == "world" )

        try p1.merge( with: p2 )

        #expect( p1.comment == "hello\nworld" )
        #expect( p2.comment == "world" )
    }

    @Test
    func mergeCommentFail() async throws
    {
        let p1 = try FITSProperty( string: "SIMPLE  = T  ".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        let p2 = try FITSProperty( string: "COMMENT world".padding( toLength: 80, withPad: " ", startingAt: 0 ) )

        #expect( throws: FITSError.self ) { try p1.merge( with: p2 ) }
        #expect( throws: FITSError.self ) { try p2.merge( with: p1 ) }
    }

    @Test
    func mergeString() async throws
    {
        let p1 = try FITSProperty( string: "FOOBAR  = 'hello&' / This is".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        let p2 = try FITSProperty( string: "CONTINUE  ', &   ' / a      ".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        let p3 = try FITSProperty( string: "CONTINUE  'world ' / comment".padding( toLength: 80, withPad: " ", startingAt: 0 ) )

        #expect( p1.kind == .string )
        #expect( p2.kind == .string )
        #expect( p3.kind == .string )

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
        let p1 = try FITSProperty( string: "FOOBAR  = 'hello&' ".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        let p2 = try FITSProperty( string: "FOOBAR  = 'hello'  ".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        let p3 = try FITSProperty( string: "CONTINUE  ', world'".padding( toLength: 80, withPad: " ", startingAt: 0 ) )

        #expect( p1.kind == .string )
        #expect( p2.kind == .string )
        #expect( p3.kind == .string )

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
        let property = try FITSProperty( string: "FOOBAR".padding( toLength: 80, withPad: " ", startingAt: 0 ) )

        #expect( property.kind    == .undefined )
        #expect( property.comment == nil )
    }

    @Test
    func mergeHistoryWithNilLeftCommentHasNoLeadingNewline() async throws
    {
        let p1 = try FITSProperty( string: "HISTORY".padding(       toLength: 80, withPad: " ", startingAt: 0 ) )
        let p2 = try FITSProperty( string: "HISTORY world".padding( toLength: 80, withPad: " ", startingAt: 0 ) )

        #expect( p1.comment == nil )
        #expect( p2.comment == "world" )

        try p1.merge( with: p2 )

        #expect( p1.comment == "world" )
    }

    @Test
    func mergeStringWithNilRightCommentHasNoTrailingNewline() async throws
    {
        let p1 = try FITSProperty( string: "FOOBAR  = 'hello&' / This is".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        let p2 = try FITSProperty( string: "CONTINUE  'world '".padding(          toLength: 80, withPad: " ", startingAt: 0 ) )

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

            let property = try FITSProperty( string: test.field.padding( toLength: 80, withPad: " ", startingAt: 0 ) )

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
        #expect( throws: FITSError.self ) { try FITSProperty( string: "CONTINUE=   ".padding( toLength: 80, withPad: " ", startingAt: 0 ) ) }
        #expect( throws: FITSError.self ) { try FITSProperty( string: "CONTINUE='' ".padding( toLength: 80, withPad: " ", startingAt: 0 ) ) }
        #expect( throws: FITSError.self ) { try FITSProperty( string: "CONTINUE= ''".padding( toLength: 80, withPad: " ", startingAt: 0 ) ) }
        #expect( throws: FITSError.self ) { try FITSProperty( string: "CONTINUE=  0".padding( toLength: 80, withPad: " ", startingAt: 0 ) ) }
    }

    @Test
    func quotesInString() async throws
    {
        let property = try FITSProperty( string: "FOOBAR  = '''hello''world'''".padding( toLength: 80, withPad: " ", startingAt: 0 ) )

        #expect( property.kind == .string )
        #expect( property.value.string != nil )
        #expect( property.value.string == "'hello'world'" )
    }

    @Test
    func valueIsTypedAndAccessorsMatchCase() async throws
    {
        let logical = try FITSProperty( string: "FOOBAR  = T".padding(    toLength: 80, withPad: " ", startingAt: 0 ) )
        let integer = try FITSProperty( string: "FOOBAR  = 42".padding(   toLength: 80, withPad: " ", startingAt: 0 ) )
        let float   = try FITSProperty( string: "FOOBAR  = 42.5".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        let string  = try FITSProperty( string: "FOOBAR  = 'hi'".padding( toLength: 80, withPad: " ", startingAt: 0 ) )

        // The case payload is exposed, and the matching accessor returns it
        // while every non-matching accessor returns nil.
        #expect( logical.value == .logical( true ) )
        #expect( logical.value.logical == true )
        #expect( logical.value.integer == nil )
        #expect( logical.value.string  == nil )

        #expect( integer.value == .integer( 42 ) )
        #expect( integer.value.integer == 42 )
        #expect( integer.value.logical == nil )

        #expect( float.value == .float( 42.5 ) )
        #expect( float.value.float == 42.5 )
        #expect( float.value.integer == nil )

        #expect( string.value == .string( "hi" ) )
        #expect( string.value.string == "hi" )
        #expect( string.value.float  == nil )

        // kind is derived from value, so it always agrees with the case.
        #expect( logical.kind == .logical )
        #expect( integer.kind == .integer )
        #expect( float.kind   == .float )
        #expect( string.kind  == .string )
    }
}
