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
        #expect( property.kind    == .empty )
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
        #expect( property.kind    == .empty )
    }
    
    @Test
    func comment() async throws
    {
        let p1 = try FITSProperty( string: "FOOBAR  = 0".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        let p2 = try FITSProperty( string: "FOOBAR  = 0 / This is a comment".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        let p3 = try FITSProperty( string: "FOOBAR      / This is a comment".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        let p4 = try FITSProperty( string: "FOOBAR        This is a comment".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        let p5 = try FITSProperty( string: "FOOBAR  =This is a comment".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        let p6 = try FITSProperty( string: "HISTORY       This is a comment".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        let p7 = try FITSProperty( string: "COMMENT       This is a comment".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        let p8 = try FITSProperty( string: "              This is a comment".padding( toLength: 80, withPad: " ", startingAt: 0 ) )
        
        #expect( p1.comment == nil )
        #expect( p2.comment == "This is a comment" )
        #expect( p3.comment == "This is a comment" )
        #expect( p4.comment == "      This is a comment" )
        #expect( p5.comment == "This is a comment" )
        #expect( p6.comment == "      This is a comment" )
        #expect( p7.comment == "      This is a comment" )
        #expect( p8.comment == "      This is a comment" )
    }
}
