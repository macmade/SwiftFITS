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

struct Test_FITSSection
{
    @Test
    func initData() async throws
    {
        let block    = try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ) )
        let section1 = try FITSSection( kind: .data, block: block )
        let section2 = try FITSSection( kind: .data, block: nil )

        #expect( section1.kind == .data )
        #expect( section2.kind == .data )

        #expect( section1.canAppendData == true )
        #expect( section2.canAppendData == true )

        #expect( section1.data.isEmpty == false )
        #expect( section2.data.isEmpty == true )
    }

    @Test
    func initHeader() async throws
    {
        let block1   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true,  keywords: [] ) )
        let block2   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: false, keywords: [] ) )
        let section1 = try FITSSection( kind: .header, block: block1 )
        let section2 = try FITSSection( kind: .header, block: block2 )
        let section3 = try FITSSection( kind: .header, block: nil )

        #expect( section1.kind == .header )
        #expect( section2.kind == .header )
        #expect( section3.kind == .header )

        #expect( section1.canAppendData == false )
        #expect( section2.canAppendData == true )
        #expect( section3.canAppendData == true )

        #expect( section1.data.isEmpty == false )
        #expect( section2.data.isEmpty == false )
        #expect( section3.data.isEmpty == true )
    }

    @Test
    func initExtension() async throws
    {
        let block1   = try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: true,  keywords: [] ) )
        let block2   = try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: false, keywords: [] ) )
        let section1 = try FITSSection( kind: .xtension, block: block1 )
        let section2 = try FITSSection( kind: .xtension, block: block2 )
        let section3 = try FITSSection( kind: .xtension, block: nil )

        #expect( section1.kind == .xtension )
        #expect( section2.kind == .xtension )
        #expect( section3.kind == .xtension )

        #expect( section1.canAppendData == false )
        #expect( section2.canAppendData == true )
        #expect( section3.canAppendData == true )

        #expect( section1.data.isEmpty == false )
        #expect( section2.data.isEmpty == false )
        #expect( section3.data.isEmpty == true )
    }

    @Test
    func dataConcatenatesBlocksInOrder() async throws
    {
        let bytes1  = TestUtilities.dataBlock( fill: 0x01 )
        let bytes2  = TestUtilities.dataBlock( fill: 0x02 )
        let section = try FITSSection( kind: .data, block: try FITSBlock( data: bytes1 ) )

        try section.append( block: try FITSBlock( data: bytes2 ) )

        #expect( section.dataSize == FITSFile.blockSize * 2 )
        #expect( section.data     == bytes1 + bytes2 )
    }

    @Test
    func appendData() async throws
    {
        let block    = try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ) )
        let section1 = try FITSSection( kind: .data, block: block )
        let section2 = try FITSSection( kind: .data, block: nil )

        #expect( throws: Never.self ) { try section1.append( block: block ) }
        #expect( throws: Never.self ) { try section2.append( block: block ) }
    }

    @Test
    func appendHeader() async throws
    {
        let block1   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true,  keywords: [] ) )
        let block2   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: false, keywords: [] ) )
        let section1 = try FITSSection( kind: .header, block: block1 )
        let section2 = try FITSSection( kind: .header, block: block2 )
        let section3 = try FITSSection( kind: .header, block: nil )

        #expect( throws: FITSError.self ) { try section1.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
        #expect( throws: Never.self     ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
        #expect( throws: Never.self     ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }

        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ) ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ) ) ) }

        #expect( throws: Never.self     ) { try section2.append( block: try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ) ) ) }
        #expect( throws: Never.self     ) { try section3.append( block: try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ) ) ) }

        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
    }

    @Test
    func appendExtension() async throws
    {
        let block1   = try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: true,  keywords: [] ) )
        let block2   = try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: false, keywords: [] ) )
        let section1 = try FITSSection( kind: .xtension, block: block1 )
        let section2 = try FITSSection( kind: .xtension, block: block2 )
        let section3 = try FITSSection( kind: .xtension, block: nil )

        #expect( throws: FITSError.self ) { try section1.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
        #expect( throws: Never.self     ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
        #expect( throws: Never.self     ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }

        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ) ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ) ) ) }

        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: true, keywords: [] ) ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: true, keywords: [] ) ) ) }

        #expect( throws: Never.self ) { try section2.append( block: try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ) ) ) }
        #expect( throws: Never.self ) { try section3.append( block: try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ) ) ) }

        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
    }

    @Test
    func mergeHistory() async throws
    {
        let keywords = [ ( "HISTORY", "hello" ), ( "HISTORY", "world" ) ]
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ) )
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
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ) )
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
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ) )
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
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ) )
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
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ) )
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
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ) )
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
        let block1    = try FITSBlock( data: try TestUtilities.headerBlock( keywords: keywords1 ) )
        let block2    = try FITSBlock( data: try TestUtilities.headerBlock( keywords: keywords2 ) )
        let section1  = try FITSSection( kind: .header, block: block1 )
        let section2  = try FITSSection( kind: .header, block: block2 )

        #expect( throws: FITSError.self ) { try section1.finalize( options: .lenient ) }
        #expect( throws: FITSError.self ) { try section2.finalize( options: .lenient ) }
    }

    @Test
    func unknownPropertiesDisabled() async throws
    {
        let keywords = [ ( "FOOBAR", "a" ) ]
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ) )
        let section  = try FITSSection( kind: .header, block: block )

        #expect( throws: FITSError.self ) { try section.finalize( options: [] ) }
    }

    @Test
    func headerWithNonPrintableByteIsRejectedWhenStrict() async throws
    {
        // FITS 4.0 restricts header text to printable ASCII (0x20...0x7E). A
        // control byte such as 0x01 must be rejected in strict mode.
        let block   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [ ( "COMMENT", "\u{01}hi" ) ] ) )
        let section = try FITSSection( kind: .header, block: block )

        #expect( throws: FITSError.self ) { try section.finalize( options: .strict ) }
    }

    @Test
    func headerWithNonPrintableByteIsToleratedWhenLenient() async throws
    {
        // In lenient mode the noncompliant byte is accepted and the record is
        // still parsed.
        let block   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [ ( "COMMENT", "\u{01}hi" ) ] ) )
        let section = try FITSSection( kind: .header, block: block )

        try section.finalize( options: .lenient )

        #expect( section.properties.first { $0.name == "COMMENT" }?.comment == "\u{01}hi" )
    }

    @Test
    func finalizeTwiceThrows() async throws
    {
        let block   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ) )
        let section = try FITSSection( kind: .header, block: block )

        try section.finalize( options: .lenient )

        #expect( throws: FITSError.self ) { try section.finalize( options: .lenient ) }
    }

    @Test
    func appendAfterFinalizeThrows() async throws
    {
        let block   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ) )
        let section = try FITSSection( kind: .header, block: block )

        try section.finalize( options: .lenient )

        #expect( throws: FITSError.self ) { try section.append( block: try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: false, keywords: [] ) ) ) }
    }

    @Test
    func description() async throws
    {
        let block   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ) )
        let section = try FITSSection( kind: .header, block: block )

        #expect( section.description.isEmpty == false )
        #expect( section.description         != _typeName( FITSSection.self, qualified: true ) )
    }

    @Test
    func descriptionReportsDataSize() async throws
    {
        let block   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: false, keywords: [] ) )
        let section = try FITSSection( kind: .header, block: block )

        #expect( section.description.contains( "Data Size:  \( FITSFile.blockSize )" ) )

        try section.append( block: try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ) ) )

        #expect( section.description.contains( "Data Size:  \( FITSFile.blockSize * 2 )" ) )
    }

    @Test
    func multipleEndMarkers() async throws
    {
        let keywords = [ ( "END", "" ) ]
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ) )
        let section  = try FITSSection( kind: .header, block: block )

        #expect( throws: FITSError.self ) { try section.finalize( options: [] ) }
    }

    @Test
    func noEndMarker() async throws
    {
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: false, keywords: [] ) )
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

        let block1    = try FITSBlock( data: try TestUtilities.headerBlock( fields: fields1 ) )
        let block2    = try FITSBlock( data: try TestUtilities.headerBlock( fields: fields2 ) )
        let section1  = try FITSSection( kind: .header, block: block1 )
        let section2  = try FITSSection( kind: .header, block: block2 )

        try section1.finalize( options: .lenient )
        try section2.finalize( options: .lenient )

        #expect( section1.properties.count == 5 )
        #expect( section2.properties.count == 5 )
    }
}
