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

struct Test_FITSSection
{
    @Test
    func initData() async throws
    {
        let block    = try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ), options: .strict )
        let section1 = try FITSSection( kind: .data, block: block )
        let section2 = try FITSSection( kind: .data, block: nil )

        #expect( section1.kind == .data )
        #expect( section2.kind == .data )

        #expect( section1.data.isEmpty == false )
        #expect( section2.data.isEmpty == true )
    }

    @Test
    func initHeader() async throws
    {
        let block1   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true,  keywords: [] ), options: .strict )
        let block2   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: false, keywords: [] ), options: .strict )
        let section1 = try FITSSection( kind: .header, block: block1 )
        let section2 = try FITSSection( kind: .header, block: block2 )
        let section3 = try FITSSection( kind: .header, block: nil )

        #expect( section1.kind == .header )
        #expect( section2.kind == .header )
        #expect( section3.kind == .header )

        #expect( section1.data.isEmpty == false )
        #expect( section2.data.isEmpty == false )
        #expect( section3.data.isEmpty == true )
    }

    @Test
    func initExtension() async throws
    {
        let block1   = try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: true,  keywords: [] ), options: .strict )
        let block2   = try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: false, keywords: [] ), options: .strict )
        let section1 = try FITSSection( kind: .xtension, block: block1 )
        let section2 = try FITSSection( kind: .xtension, block: block2 )
        let section3 = try FITSSection( kind: .xtension, block: nil )

        #expect( section1.kind == .xtension )
        #expect( section2.kind == .xtension )
        #expect( section3.kind == .xtension )

        #expect( section1.data.isEmpty == false )
        #expect( section2.data.isEmpty == false )
        #expect( section3.data.isEmpty == true )
    }

    @Test
    func dataConcatenatesBlocksInOrder() async throws
    {
        let bytes1  = TestUtilities.dataBlock( fill: 0x01 )
        let bytes2  = TestUtilities.dataBlock( fill: 0x02 )
        let section = try FITSSection( kind: .data, block: try FITSBlock( data: bytes1, options: .strict ) )

        try section.append( block: try FITSBlock( data: bytes2, options: .strict ) )

        #expect( section.dataSize == FITSFile.blockSize * 2 )
        #expect( section.data     == bytes1 + bytes2 )
    }

    @Test
    func appendData() async throws
    {
        let block    = try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ), options: .strict )
        let section1 = try FITSSection( kind: .data, block: block )
        let section2 = try FITSSection( kind: .data, block: nil )

        #expect( throws: Never.self ) { try section1.append( block: block ) }
        #expect( throws: Never.self ) { try section2.append( block: block ) }
    }

    @Test
    func appendHeader() async throws
    {
        let block1   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true,  keywords: [] ), options: .strict )
        let block2   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: false, keywords: [] ), options: .strict )
        let section1 = try FITSSection( kind: .header, block: block1 )
        let section2 = try FITSSection( kind: .header, block: block2 )
        let section3 = try FITSSection( kind: .header, block: nil )

        #expect( throws: FITSError.self ) { try section1.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ), options: .strict ) ) }
        #expect( throws: Never.self     ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ), options: .strict ) ) }
        #expect( throws: Never.self     ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ), options: .strict ) ) }

        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ), options: .strict ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ), options: .strict ) ) }

        #expect( throws: Never.self     ) { try section2.append( block: try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ), options: .strict ) ) }
        #expect( throws: Never.self     ) { try section3.append( block: try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ), options: .strict ) ) }

        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ), options: .strict ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ), options: .strict ) ) }
    }

    @Test
    func appendExtension() async throws
    {
        let block1   = try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: true,  keywords: [] ), options: .strict )
        let block2   = try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: false, keywords: [] ), options: .strict )
        let section1 = try FITSSection( kind: .xtension, block: block1 )
        let section2 = try FITSSection( kind: .xtension, block: block2 )
        let section3 = try FITSSection( kind: .xtension, block: nil )

        #expect( throws: FITSError.self ) { try section1.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ), options: .strict ) ) }
        #expect( throws: Never.self     ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ), options: .strict ) ) }
        #expect( throws: Never.self     ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ), options: .strict ) ) }

        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ), options: .strict ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ), options: .strict ) ) }

        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: true, keywords: [] ), options: .strict ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: true, keywords: [] ), options: .strict ) ) }

        #expect( throws: Never.self ) { try section2.append( block: try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ), options: .strict ) ) }
        #expect( throws: Never.self ) { try section3.append( block: try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ), options: .strict ) ) }

        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ), options: .strict ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ), options: .strict ) ) }
    }

    @Test
    func mergeHistory() async throws
    {
        let keywords = [ ( "HISTORY", "hello" ), ( "HISTORY", "world" ) ]
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ), options: .strict )
        let section  = try FITSSection( kind: .header, block: block )

        try section.finalize( options: .lenient )

        let property = section.properties.filter { $0.name == "HISTORY" }.first

        #expect( property          != nil )
        #expect( property?.comment == "hello\nworld" )
    }

    @Test
    func mergeHistoryDisabled() async throws
    {
        let keywords = [ ( "HISTORY", "hello" ), ( "HISTORY", "world" ) ]
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ), options: .strict )
        let section  = try FITSSection( kind: .header, block: block )

        try section.finalize( options: [] )

        let properties = section.properties.filter { $0.name == "HISTORY" }

        try #require( properties.count == 2 )

        #expect( properties[ 0 ].comment == "hello" )
        #expect( properties[ 1 ].comment == "world" )
    }

    @Test
    func mergeComment() async throws
    {
        let keywords = [ ( "COMMENT", "hello" ), ( "COMMENT", "world" ) ]
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ), options: .strict )
        let section  = try FITSSection( kind: .header, block: block )

        try section.finalize( options: .lenient )

        let property = section.properties.filter { $0.name == "COMMENT" }.first

        #expect( property          != nil )
        #expect( property?.comment == "hello\nworld" )
    }

    @Test
    func mergeCommentDisabled() async throws
    {
        let keywords = [ ( "COMMENT", "hello" ), ( "COMMENT", "world" ) ]
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ), options: .strict )
        let section  = try FITSSection( kind: .header, block: block )

        try section.finalize( options: [] )

        let properties = section.properties.filter { $0.name == "COMMENT" }

        try #require( properties.count == 2 )

        #expect( properties[ 0 ].comment == "hello" )
        #expect( properties[ 1 ].comment == "world" )
    }

    @Test
    func mergeString() async throws
    {
        let keywords = [ ( "FOOBAR", "'hello&'" ), ( "CONTINUE", "', world'" ) ]
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ), options: .strict )
        let section  = try FITSSection( kind: .header, block: block )

        try section.finalize( options: .mergeStringProperties )

        let property = section.properties.filter { $0.name == "FOOBAR" }.first

        #expect( property                   != nil )
        #expect( property?.value.string == "hello, world" )
    }

    @Test
    func mergeStringDisabled() async throws
    {
        let keywords = [ ( "FOOBAR", "'hello&'" ), ( "CONTINUE", "', world'" ) ]
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ), options: .strict )
        let section  = try FITSSection( kind: .header, block: block )

        try section.finalize( options: [] )

        let p1 = section.properties.filter { $0.name == "FOOBAR" }.first
        let p2 = section.properties.filter { $0.name == "CONTINUE" }.first

        #expect( p1 != nil )
        #expect( p2 != nil )

        #expect( p1?.value.string == "hello&" )
        #expect( p2?.value.string == ", world" )
    }

    @Test
    func mergeStringFail() async throws
    {
        let keywords1 = [ ( "FOOBAR", "'hello'" ), ( "CONTINUE", "', world'" ), ( "END", "" ) ]
        let keywords2 = [ ( "CONTINUE", "', world'" ), ( "END", "" ) ]
        let block1    = try FITSBlock( data: try TestUtilities.headerBlock( keywords: keywords1 ), options: .strict )
        let block2    = try FITSBlock( data: try TestUtilities.headerBlock( keywords: keywords2 ), options: .strict )
        let section1  = try FITSSection( kind: .header, block: block1 )
        let section2  = try FITSSection( kind: .header, block: block2 )

        #expect( throws: FITSError.self ) { try section1.finalize( options: .strict ) }
        #expect( throws: FITSError.self ) { try section2.finalize( options: .strict ) }
    }

    @Test
    func orphanedContinueIsStandaloneWithFlag() async throws
    {
        // Two orphaned-CONTINUE cases: a CONTINUE after a non-&-terminated
        // string, and a CONTINUE with no predecessor at all. Under
        // allowOrphanedContinue both are kept as standalone properties rather
        // than rejecting the section.
        let keywords1 = [ ( "FOOBAR", "'hello'" ), ( "CONTINUE", "', world'" ), ( "END", "" ) ]
        let keywords2 = [ ( "CONTINUE", "', world'" ), ( "END", "" ) ]
        let block1    = try FITSBlock( data: try TestUtilities.headerBlock( keywords: keywords1 ), options: .strict )
        let block2    = try FITSBlock( data: try TestUtilities.headerBlock( keywords: keywords2 ), options: .strict )
        let section1  = try FITSSection( kind: .header, block: block1 )
        let section2  = try FITSSection( kind: .header, block: block2 )
        let options: FITSParsingOptions = [ .mergeStringProperties, .allowOrphanedContinue ]

        try section1.finalize( options: options )
        try section2.finalize( options: options )

        // The non-& predecessor is left untouched; the CONTINUE stands alone.
        #expect( section1.properties.first { $0.name == "FOOBAR"   }?.value.string == "hello" )
        #expect( section1.properties.first { $0.name == "CONTINUE" }?.value.string == ", world" )
        #expect( section2.properties.first { $0.name == "CONTINUE" }?.value.string == ", world" )
    }

    @Test
    func unknownPropertiesDisabled() async throws
    {
        let keywords = [ ( "FOOBAR", "a" ) ]
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ), options: .strict )
        let section  = try FITSSection( kind: .header, block: block )

        #expect( throws: FITSError.self ) { try section.finalize( options: [] ) }
    }

    @Test
    func headerWithNonPrintableByteIsRejectedWhenStrict() async throws
    {
        // FITS 4.0 restricts header text to printable ASCII (0x20...0x7E). A
        // control byte such as 0x01 must be rejected in strict mode.
        let block   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [ ( "COMMENT", "\u{01}hi" ) ] ), options: .strict )
        let section = try FITSSection( kind: .header, block: block )

        #expect( throws: FITSError.self ) { try section.finalize( options: .strict ) }
    }

    @Test
    func headerWithNonPrintableByteIsToleratedWhenLenient() async throws
    {
        // In lenient mode the noncompliant byte is accepted and the record is
        // still parsed.
        let block   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [ ( "COMMENT", "\u{01}hi" ) ] ), options: .strict )
        let section = try FITSSection( kind: .header, block: block )

        try section.finalize( options: .lenient )

        #expect( section.properties.first { $0.name == "COMMENT" }?.comment == "\u{01}hi" )
    }

    @Test
    func finalizeTwiceThrows() async throws
    {
        let block   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ), options: .strict )
        let section = try FITSSection( kind: .header, block: block )

        try section.finalize( options: .lenient )

        #expect( throws: FITSError.self ) { try section.finalize( options: .lenient ) }
    }

    @Test
    func appendAfterFinalizeThrows() async throws
    {
        let block   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ), options: .strict )
        let section = try FITSSection( kind: .header, block: block )

        try section.finalize( options: .lenient )

        #expect( throws: FITSError.self ) { try section.append( block: try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: false, keywords: [] ), options: .strict ) ) }
    }

    @Test
    func description() async throws
    {
        let block   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ), options: .strict )
        let section = try FITSSection( kind: .header, block: block )

        #expect( section.description.isEmpty == false )
        #expect( section.description         != _typeName( FITSSection.self, qualified: true ) )
    }

    @Test
    func descriptionReportsDataSize() async throws
    {
        let block   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: false, keywords: [] ), options: .strict )
        let section = try FITSSection( kind: .header, block: block )

        #expect( section.description.contains( "Data Size:  \( FITSFile.blockSize )" ) )

        try section.append( block: try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ), options: .strict ) )

        #expect( section.description.contains( "Data Size:  \( FITSFile.blockSize * 2 )" ) )
    }

    @Test
    func multipleEndMarkers() async throws
    {
        let keywords = [ ( "END", "" ) ]
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ), options: .strict )
        let section  = try FITSSection( kind: .header, block: block )

        #expect( throws: FITSError.self ) { try section.finalize( options: [] ) }
    }

    @Test
    func noEndMarker() async throws
    {
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: false, keywords: [] ), options: .strict )
        let section  = try FITSSection( kind: .header, block: block )

        #expect( throws: FITSError.self ) { try section.finalize( options: [] ) }
    }

    @Test
    func removeEmptyPropertiesAtEnd() async throws
    {
        let fields = [
            "SIMPLE  = T",
            "BITPIX  = 8",
            "NAXIS   = 0",
            "           ",
            "FOOBAR  = 1",
            "           ",
            "           ",
        ]

        let fields1 = [ fields.dropLast( 2 ), [ "END" ] ].flatMap { $0 }
        let fields2 = [ fields,               [ "END" ] ].flatMap { $0 }

        try #require( fields1.count == 6 )
        try #require( fields2.count == 8 )

        let block1    = try FITSBlock( data: try TestUtilities.headerBlock( fields: fields1 ), options: .strict )
        let block2    = try FITSBlock( data: try TestUtilities.headerBlock( fields: fields2 ), options: .strict )
        let section1  = try FITSSection( kind: .header, block: block1 )
        let section2  = try FITSSection( kind: .header, block: block2 )

        try section1.finalize( options: .lenient )
        try section2.finalize( options: .lenient )

        #expect( section1.properties.count == 5 )
        #expect( section2.properties.count == 5 )
    }

    @Test
    func allBlankHeaderTrimsToEmptyProperties() async throws
    {
        // A header of only blank records before END: the trailing-blank trimming
        // applies symmetrically to the degenerate all-blank case, leaving no
        // properties rather than a list of blank records.
        let fields  = [ "           ", "           ", "END" ]
        let block   = try FITSBlock( data: try TestUtilities.headerBlock( fields: fields ), options: .strict )
        let section = try FITSSection( kind: .header, block: block )

        try section.finalize( options: .strict )

        #expect( section.properties.isEmpty )
    }

    @Test
    func nonBlankContentAfterEndIsRejectedWhenStrict() async throws
    {
        // A non-blank record following the END marker is noncompliant. Strict
        // validation rejects it rather than silently dropping it.
        let fields  = [ "SIMPLE  = T", "BITPIX  = 8", "NAXIS   = 0", "END", "FOOBAR  = 1" ]
        let block   = try FITSBlock( data: try TestUtilities.headerBlock( fields: fields ), options: .strict )
        let section = try FITSSection( kind: .header, block: block )

        #expect( throws: FITSError.self ) { try section.finalize( options: .strict ) }
    }

    @Test
    func nonBlankContentAfterEndIsToleratedWhenLenient() async throws
    {
        // allowContentAfterEnd keeps the silent-truncation behavior: the record
        // after END is dropped from properties, but its bytes survive in data.
        let fields  = [ "SIMPLE  = T", "BITPIX  = 8", "NAXIS   = 0", "END", "FOOBAR  = 1" ]
        let block   = try FITSBlock( data: try TestUtilities.headerBlock( fields: fields ), options: .lenient )
        let section = try FITSSection( kind: .header, block: block )

        try section.finalize( options: .lenient )

        #expect( section.properties.count == 3 )
        #expect( section.properties.contains { $0.name == "FOOBAR" } == false )
        #expect( section.data == block.data )
    }

    @Test
    func blankContentAfterEndIsAcceptedInBothModes() async throws
    {
        // Blank padding after END is compliant and must be accepted regardless
        // of mode, with the trailing blanks trimmed from properties.
        let fields = [ "SIMPLE  = T", "BITPIX  = 8", "NAXIS   = 0", "END", "           ", "           " ]

        try [ FITSParsingOptions.strict, .lenient ].forEach
        {
            options in

            let block   = try FITSBlock( data: try TestUtilities.headerBlock( fields: fields ), options: options )
            let section = try FITSSection( kind: .header, block: block )

            try section.finalize( options: options )

            #expect( section.properties.count == 3 )
        }
    }

    @Test
    func keywordSubscriptReturnsFirstMatch() async throws
    {
        // Two records share the keyword FOO; the subscript returns the first.
        let block = try TestUtilities.headerBlock(
            keywords:
            [
                ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "0" ),
                ( "FOO", "1" ), ( "FOO", "2" ), ( "END", "" ),
            ]
        )
        let file   = try FITSFile( data: block, options: .lenient )
        let header = try #require( file.header )

        #expect( header[ "FOO" ]?.value.integer == 1 )
        #expect( header[ "MISSING" ] == nil )
    }

    @Test
    func typedGeometryAccessorsReturnParsedValues() async throws
    {
        // The geometry implies a data segment, but no data blocks follow; lenient
        // tolerates the shortfall, so the header and its accessors are available.
        let block = try TestUtilities.headerBlock(
            keywords:
            [
                ( "SIMPLE", "T" ), ( "BITPIX", "16" ), ( "NAXIS", "2" ),
                ( "NAXIS1", "100" ), ( "NAXIS2", "200" ), ( "END", "" ),
            ]
        )
        let file   = try FITSFile( data: block, options: .lenient )
        let header = try #require( file.header )

        #expect( header.bitpix     == 16 )
        #expect( header.naxis      == 2 )
        #expect( header.naxis( 1 ) == 100 )
        #expect( header.naxis( 2 ) == 200 )
        #expect( header.naxis( 3 ) == nil )
    }

    @Test
    func typedGeometryAccessorsAreNilWhenAbsent() async throws
    {
        // A data section carries no parsed properties, so every geometry
        // accessor is nil.
        let header = try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1" ), ( "NAXIS1", "2880" ), ( "END", "" ) ] )
        let data   = TestUtilities.dataBlock( fill: 0x00 )
        let file   = try FITSFile( data: header + data, options: .strict )
        let segment = try #require( file.sections.first { $0.kind == .data } )

        #expect( segment.bitpix     == nil )
        #expect( segment.naxis      == nil )
        #expect( segment.naxis( 1 ) == nil )
        #expect( segment[ "BITPIX" ] == nil )
    }
}
