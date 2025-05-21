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

class TestUtilities
{
    public static var testFiles: [ URL ]
    {
        [
            Bundle( for: self ).urls( forResourcesWithExtension: "fits", subdirectory: nil ) ?? [],
            Bundle( for: self ).urls( forResourcesWithExtension: "fit",  subdirectory: nil ) ?? [],
        ]
        .flatMap
        {
            $0
        }
        .sorted
        {
            $0.lastPathComponent < $1.lastPathComponent
        }
    }
    
    class func dataBlock( fill: UInt8 ) -> Data
    {
        Data( repeating: fill, count: FITSFile.blockSize )
    }
    
    class func headerBlock( keywords: [ ( name: String, value: String ) ] ) throws -> Data
    {
        let lines = try keywords.map
        {
            guard $0.name.count <= 8
            else
            {
                throw FITSError.genericError( reason: "Keyword name is too long" )
            }
            
            let name = $0.name.padding( toLength: 8, withPad: "\u{20}", startingAt: 0 )
            
            let text = if $0.name == "END"
            {
                "\( name )"
            }
            else if $0.name == "HISTORY" || $0.name == "COMMENT"
            {
                "\( name )\( $0.value )"
            }
            else if $0.name == "CONTINUE"
            {
                "\( name )  \( $0.value )"
            }
            else
            {
                "\( name )= \( $0.value )"
            }
            
            return text
        }
        
        return try self.headerBlock( fields: lines )
    }
    
    class func headerBlock( fields: [ String ] ) throws -> Data
    {
        let text = try fields.map
        {
            guard $0.count <= 80
            else
            {
                throw FITSError.genericError( reason: "Keyword line is too long" )
            }
            
            return $0.padding( toLength: 80, withPad: "\u{20}", startingAt: 0 )
        }
        .joined( separator: "" )
        
        if text.count > FITSFile.blockSize
        {
            throw FITSError.genericError( reason: "Header block is too long" )
        }
        
        guard let data = text.padding( toLength: FITSFile.blockSize, withPad: "\u{20}", startingAt: 0 ).data( using: .ascii )
        else
        {
            throw FITSError.genericError( reason: "Cannot convert string to ASCII data" )
        }
        
        return data
    }
    
    class func standardHeaderBlock( includeEndMarker: Bool, keywords: [ ( name: String, value: String ) ] ) throws -> Data
    {
        let end:    [ ( name: String, value: String ) ] = includeEndMarker ? [ ( "END", "" ) ] : []
        let header: [ ( name: String, value: String ) ] = [
            ( "SIMPLE", "T" ),
            ( "BITPIX", "8" ),
            ( "NAXIS",  "0" ),
        ]
        
        return try self.headerBlock( keywords: [ header, keywords, end ].flatMap( { $0 } ) )
    }
    
    class func standardExtensionBlock( includeEndMarker: Bool, keywords: [ ( name: String, value: String ) ] ) throws -> Data
    {
        let end:    [ ( name: String, value: String ) ] = includeEndMarker ? [ ( "END", "" ) ] : []
        let header: [ ( name: String, value: String ) ] = [
            ( "XTENSION", "'TABLE    '" ),
            ( "BITPIX",   "8"           ),
            ( "NAXIS",    "0"           ),
        ]
        
        return try self.headerBlock( keywords: [ header, keywords, end ].flatMap( { $0 } ) )
    }
    
    @Test
    func hasTestFiles() async throws
    {
        #expect( TestUtilities.testFiles.isEmpty == false )
    }
    
    @Test
    func dataBlock() async throws
    {
        #expect( TestUtilities.dataBlock( fill: 0x00 ).count == FITSFile.blockSize )
        #expect( TestUtilities.dataBlock( fill: 0xFF ).count == FITSFile.blockSize )
    }
    
    @Test
    func headerBlockWithKeywords() async throws
    {
        let block = try TestUtilities.headerBlock(
            keywords:
            [
                ( "SIMPLE",   "T"        ),
                ( "BITPIX",   "8"        ),
                ( "NAXIS",    "0"        ),
                ( "FOO",      "'Test&'"  ),
                ( "CONTINUE", "'Test'"   ),
                ( "HISTORY",  "Test"     ),
                ( "COMMENT",  "Test"     ),
                ( "END",      ""         )
            ]
        )
        
        try #require( block.count == FITSFile.blockSize )
        
        let chunks  = try block.chunked( by: 80 )
        let strings = try chunks.map
        {
            try #require( String( data: $0, encoding: .ascii ) )
        }
        
        #expect( strings[ 0 ] == "SIMPLE  = T                                                                     " )
        #expect( strings[ 1 ] == "BITPIX  = 8                                                                     " )
        #expect( strings[ 2 ] == "NAXIS   = 0                                                                     " )
        #expect( strings[ 3 ] == "FOO     = 'Test&'                                                               " )
        #expect( strings[ 4 ] == "CONTINUE  'Test'                                                                " )
        #expect( strings[ 5 ] == "HISTORY Test                                                                    " )
        #expect( strings[ 6 ] == "COMMENT Test                                                                    " )
        #expect( strings[ 7 ] == "END                                                                             " )
        
        strings.dropFirst( 8 ).forEach
        {
            #expect( $0.unicodeScalars.allSatisfy( { $0 == " " } ) )
        }
    }
    
    @Test
    func headerBlockWithFields() async throws
    {
        let block = try TestUtilities.headerBlock(
            fields:
            [
                ( "SIMPLE  = T" ),
                ( "BITPIX  = 8" ),
                ( "NAXIS   = 0" ),
                ( "END" )
            ]
        )
        
        try #require( block.count == FITSFile.blockSize )
        
        let chunks  = try block.chunked( by: 80 )
        let strings = try chunks.map
        {
            try #require( String( data: $0, encoding: .ascii ) )
        }
        
        #expect( strings[ 0 ] == "SIMPLE  = T                                                                     " )
        #expect( strings[ 1 ] == "BITPIX  = 8                                                                     " )
        #expect( strings[ 2 ] == "NAXIS   = 0                                                                     " )
        #expect( strings[ 3 ] == "END                                                                             " )
        
        strings.dropFirst( 4 ).forEach
        {
            #expect( $0.unicodeScalars.allSatisfy( { $0 == " " } ) )
        }
    }
    
    @Test
    func standardHeaderBlockWithEndMarker() async throws
    {
        let block = try TestUtilities.standardHeaderBlock(
            includeEndMarker: true,
            keywords:
            [
                ( "FOO", "42" ),
                ( "BAR", "00" ),
            ]
        )
        
        try #require( block.count == FITSFile.blockSize )
        
        let chunks  = try block.chunked( by: 80 )
        let strings = try chunks.map
        {
            try #require( String( data: $0, encoding: .ascii ) )
        }
        
        #expect( strings[ 0 ] == "SIMPLE  = T                                                                     " )
        #expect( strings[ 1 ] == "BITPIX  = 8                                                                     " )
        #expect( strings[ 2 ] == "NAXIS   = 0                                                                     " )
        #expect( strings[ 3 ] == "FOO     = 42                                                                    " )
        #expect( strings[ 4 ] == "BAR     = 00                                                                    " )
        #expect( strings[ 5 ] == "END                                                                             " )
        
        strings.dropFirst( 6 ).forEach
        {
            #expect( $0.unicodeScalars.allSatisfy( { $0 == " " } ) )
        }
    }
    
    @Test
    func standardHeaderBlockWithoutEndMarker() async throws
    {
        let block = try TestUtilities.standardHeaderBlock(
            includeEndMarker: false,
            keywords:
            [
                ( "FOO", "42" ),
                ( "BAR", "00" ),
            ]
        )
        
        try #require( block.count == FITSFile.blockSize )
        
        let chunks  = try block.chunked( by: 80 )
        let strings = try chunks.map
        {
            try #require( String( data: $0, encoding: .ascii ) )
        }
        
        #expect( strings[ 0 ] == "SIMPLE  = T                                                                     " )
        #expect( strings[ 1 ] == "BITPIX  = 8                                                                     " )
        #expect( strings[ 2 ] == "NAXIS   = 0                                                                     " )
        #expect( strings[ 3 ] == "FOO     = 42                                                                    " )
        #expect( strings[ 4 ] == "BAR     = 00                                                                    " )
        
        strings.dropFirst( 5 ).forEach
        {
            #expect( $0.unicodeScalars.allSatisfy( { $0 == " " } ) )
        }
    }
    
    @Test
    func standardExtensionBlockWithEndMarker() async throws
    {
        let block = try TestUtilities.standardExtensionBlock(
            includeEndMarker: true,
            keywords:
            [
                ( "FOO", "42" ),
                ( "BAR", "00" ),
            ]
        )
        
        try #require( block.count == FITSFile.blockSize )
        
        let chunks  = try block.chunked( by: 80 )
        let strings = try chunks.map
        {
            try #require( String( data: $0, encoding: .ascii ) )
        }
        
        #expect( strings[ 0 ] == "XTENSION= 'TABLE    '                                                           " )
        #expect( strings[ 1 ] == "BITPIX  = 8                                                                     " )
        #expect( strings[ 2 ] == "NAXIS   = 0                                                                     " )
        #expect( strings[ 3 ] == "FOO     = 42                                                                    " )
        #expect( strings[ 4 ] == "BAR     = 00                                                                    " )
        #expect( strings[ 5 ] == "END                                                                             " )
        
        strings.dropFirst( 6 ).forEach
        {
            #expect( $0.unicodeScalars.allSatisfy( { $0 == " " } ) )
        }
    }
    
    @Test
    func standardExtensionBlockWithoutEndMarker() async throws
    {
        let block = try TestUtilities.standardExtensionBlock(
            includeEndMarker: false,
            keywords:
            [
                ( "FOO", "42" ),
                ( "BAR", "00" ),
            ]
        )
        
        try #require( block.count == FITSFile.blockSize )
        
        let chunks  = try block.chunked( by: 80 )
        let strings = try chunks.map
        {
            try #require( String( data: $0, encoding: .ascii ) )
        }
        
        #expect( strings[ 0 ] == "XTENSION= 'TABLE    '                                                           " )
        #expect( strings[ 1 ] == "BITPIX  = 8                                                                     " )
        #expect( strings[ 2 ] == "NAXIS   = 0                                                                     " )
        #expect( strings[ 3 ] == "FOO     = 42                                                                    " )
        #expect( strings[ 4 ] == "BAR     = 00                                                                    " )
        
        strings.dropFirst( 5 ).forEach
        {
            #expect( $0.unicodeScalars.allSatisfy( { $0 == " " } ) )
        }
    }
}
