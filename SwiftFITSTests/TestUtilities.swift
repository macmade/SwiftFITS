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

/// Shared fixtures and block-construction helpers for the test suite.
class TestUtilities
{
    /// The sample `.fits`/`.fit` files used as parsing fixtures.
    ///
    /// Under SwiftPM the fixtures are located relative to this source file's
    /// `#filePath` (they live at the repository root, outside any target).
    /// In a bundled build they are loaded from the test bundle's resources.
    /// Returned sorted by file name.
    public static var testFiles: [ URL ]
    {
        #if SWIFT_PACKAGE

        // The heavy "Test Files" fixtures live at the repository root, which
        // is outside any SPM target directory, so they cannot be bundled as
        // package resources. A test target is only ever run from its own
        // checkout, so we locate the fixtures relative to this source file's
        // compile-time path (#filePath -> SwiftFITSTests/ -> repository root).
        let root = URL( fileURLWithPath: #filePath )
            .deletingLastPathComponent() // SwiftFITSTests
            .deletingLastPathComponent() // repository root
            .appendingPathComponent( "Test Files" )

        guard let enumerator = FileManager.default.enumerator( at: root, includingPropertiesForKeys: nil )
        else
        {
            return []
        }

        return enumerator.compactMap { $0 as? URL }.filter
        {
            $0.pathExtension == "fits" || $0.pathExtension == "fit"
        }
        .sorted
        {
            $0.lastPathComponent < $1.lastPathComponent
        }

        #else

        return [
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

        #endif
    }

    /// Builds a single full-size block filled with a repeated byte.
    ///
    /// - Parameter fill: The byte to repeat across the whole block.
    /// - Returns: A ``FITSFile/blockSize``-byte block of `fill` bytes.
    class func dataBlock( fill: UInt8 ) -> Data
    {
        Data( repeating: fill, count: FITSFile.blockSize )
    }

    /// Builds a header block from keyword/value pairs.
    ///
    /// Each pair is rendered as an 80-character record, formatting `END`,
    /// `HISTORY`/`COMMENT` and `CONTINUE` keywords according to their syntax
    /// and using the `keyword= value` form for everything else.
    ///
    /// - Parameter keywords: The keyword name/value pairs to render.
    /// - Returns: A full-size, space-padded header block.
    /// - Throws: ``TestError/invalid(reason:)`` if a keyword name exceeds 8
    ///   characters or the block overflows.
    class func headerBlock( keywords: [ ( name: String, value: String ) ] ) throws -> Data
    {
        let lines = try keywords.map
        {
            guard $0.name.count <= 8
            else
            {
                throw TestError.invalid( reason: "Keyword name is too long" )
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

    /// Builds a header block from pre-formatted record strings.
    ///
    /// Each field is padded to 80 characters and the assembled text is padded
    /// to a full block.
    ///
    /// - Parameter fields: The record strings, each at most 80 characters.
    /// - Returns: A full-size, space-padded header block.
    /// - Throws: ``TestError/invalid(reason:)`` if a field exceeds 80
    ///   characters, the records overflow a block, or the text is not ASCII.
    class func headerBlock( fields: [ String ] ) throws -> Data
    {
        let text = try fields.map
        {
            guard $0.count <= 80
            else
            {
                throw TestError.invalid( reason: "Keyword line is too long" )
            }

            return $0.padding( toLength: 80, withPad: "\u{20}", startingAt: 0 )
        }
        .joined( separator: "" )

        if text.count > FITSFile.blockSize
        {
            throw TestError.invalid( reason: "Header block is too long" )
        }

        guard let data = text.padding( toLength: FITSFile.blockSize, withPad: "\u{20}", startingAt: 0 ).data( using: .ascii )
        else
        {
            throw TestError.invalid( reason: "Cannot convert string to ASCII data" )
        }

        return data
    }

    /// Builds a valid primary-header block prefixed with the mandatory keywords.
    ///
    /// Prepends `SIMPLE`/`BITPIX`/`NAXIS`, appends the given keywords, and
    /// optionally adds an `END` marker.
    ///
    /// - Parameters:
    ///   - includeEndMarker: Whether to append the `END` record.
    ///   - keywords: Additional keyword name/value pairs to include.
    /// - Returns: A full-size header block.
    /// - Throws: ``TestError/invalid(reason:)`` if block construction fails.
    class func standardHeaderBlock( includeEndMarker: Bool, keywords: [ ( name: String, value: String ) ] ) throws -> Data
    {
        let end:    [ ( name: String, value: String ) ] = includeEndMarker ? [ ( "END", "" ) ] : []
        let header: [ ( name: String, value: String ) ] = [
            ( "SIMPLE", "T" ),
            ( "BITPIX", "8" ),
            ( "NAXIS",  "0" ),
        ]

        return try self.headerBlock( keywords: [ header, keywords, end ].flatMap { $0 } )
    }

    /// Builds a valid extension-header block prefixed with the mandatory keywords.
    ///
    /// Prepends `XTENSION`/`BITPIX`/`NAXIS`, appends the given keywords, and
    /// optionally adds an `END` marker.
    ///
    /// - Parameters:
    ///   - includeEndMarker: Whether to append the `END` record.
    ///   - keywords: Additional keyword name/value pairs to include.
    /// - Returns: A full-size extension-header block.
    /// - Throws: ``TestError/invalid(reason:)`` if block construction fails.
    class func standardExtensionBlock( includeEndMarker: Bool, keywords: [ ( name: String, value: String ) ] ) throws -> Data
    {
        let end:    [ ( name: String, value: String ) ] = includeEndMarker ? [ ( "END", "" ) ] : []
        let header: [ ( name: String, value: String ) ] = [
            ( "XTENSION", "'TABLE    '" ),
            ( "BITPIX",   "8"           ),
            ( "NAXIS",    "0"           ),
        ]

        return try self.headerBlock( keywords: [ header, keywords, end ].flatMap { $0 } )
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
                ( "END",      ""         ),
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
            #expect( $0.unicodeScalars.allSatisfy { $0 == " " } )
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
                ( "END" ),
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
            #expect( $0.unicodeScalars.allSatisfy { $0 == " " } )
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
            #expect( $0.unicodeScalars.allSatisfy { $0 == " " } )
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
            #expect( $0.unicodeScalars.allSatisfy { $0 == " " } )
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
            #expect( $0.unicodeScalars.allSatisfy { $0 == " " } )
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
            #expect( $0.unicodeScalars.allSatisfy { $0 == " " } )
        }
    }
}
