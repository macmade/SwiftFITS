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
import Testing
@testable import SwiftFITS

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
        #expect( property.value   == nil )
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
        #expect( property.value   == nil )
        #expect( property.comment == nil )
        #expect( property.kind    == .undefined )
    }
    
    @Test
    func name() async throws
    {
        let tests: [ ( data: String, name: String ) ] =
        [
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
        let tests: [ ( data: String, comment: String? ) ] =
        [
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
        let tests: [ ( data: String, value: Bool ) ] =
        [
            ( "FOOBAR  = T", true ),
            ( "FOOBAR  = F", false ),
        ]
        
        try tests.forEach
        {
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ) )
            
            #expect( property.kind == .logical,           "Data: \( $0.data )" )
            #expect( property.value is Bool,              "Data: \( $0.data )" )
            #expect( property.value as? Bool == $0.value, "Data: \( $0.data )" )
        }
    }
    
    @Test
    func integer() async throws
    {
        let tests: [ ( data: String, value: Int64 ) ] =
        [
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
            #expect( property.value is Int64,              "Data: \( $0.data )" )
            #expect( property.value as? Int64 == $0.value, "Data: \( $0.data )" )
        }
    }
    
    @Test
    func float() async throws
    {
        let tests: [ ( data: String, value: Double ) ] =
        [
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
            #expect( property.value is Double,              "Data: \( $0.data )" )
            #expect( property.value as? Double == $0.value, "Data: \( $0.data )" )
        }
    }
    
    @Test
    func string() async throws
    {
        let tests: [ ( data: String, value: String ) ] =
        [
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
            #expect( property.value is String,              "Data: \( $0.data )" )
            #expect( property.value as? String == $0.value, "Data: \( $0.data )" )
        }
    }
    
    @Test
    func undefined() async throws
    {
        let tests: [ ( data: String, comment: String? ) ] =
        [
            ( "FOOBAR  =                    ", nil ),
            ( "FOOBAR  =/ This is a comment ", "/ This is a comment" ),
            ( "FOOBAR  = / This is a comment", "This is a comment" ),
        ]
        
        try tests.forEach
        {
            let property = try FITSProperty( string: $0.data.padding( toLength: 80, withPad: " ", startingAt: 0 ) )
            
            #expect( property.kind    == .undefined, "Data: \( $0.data )" )
            #expect( property.value   == nil,        "Data: \( $0.data )" )
            #expect( property.comment == $0.comment, "Data: \( $0.data )" )
        }
    }
    
    @Test
    func unknown() async throws
    {
        let tests: [ ( data: String, value: String, comment: String? ) ] =
        [
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
            
            #expect( property.kind    == .unknown,          "Data: \( $0.data )" )
            #expect( property.value is String,              "Data: \( $0.data )" )
            #expect( property.value as? String == $0.value, "Data: \( $0.data )" )
            #expect( property.comment == $0.comment,        "Data: \( $0.data )" )
        }
    }
}
