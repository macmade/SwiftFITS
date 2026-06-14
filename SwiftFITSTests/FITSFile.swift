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

struct Test_FITSFile
{
    @Test
    func parseAllTestFiles() async throws
    {
        try TestUtilities.testFiles.forEach
        {
            let _ = try FITSFile( url: $0 )
        }
    }

    @Test
    func allTestFilesRoundTrip() async throws
    {
        // Geometry-driven parsing assigns every block to exactly one section in
        // file order, so re-serializing must reproduce the original bytes.
        try TestUtilities.testFiles.forEach
        {
            let url  = $0
            let data = try Data( contentsOf: url )
            let file = try FITSFile( data: data )

            #expect( file.data == data, "Round-trip mismatch for \( url.lastPathComponent )" )
        }
    }

    @Test
    func invalidURL() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( url: URL( fileURLWithPath: "/foo/bar.fits" ) ) }
    }

    @Test
    func emptyFile() async throws
    {
        let url = URL( fileURLWithPath: NSTemporaryDirectory(), isDirectory: true ).appending( component: UUID().uuidString ).appendingPathExtension( "fits" )

        try #require( FileManager.default.fileExists( atPath: url.path ) == false )
        try #require( FileManager.default.createFile( atPath: url.path, contents: Data(), attributes: nil ) )

        #expect( throws: FITSError.self ) { try FITSFile( url: url ) }

        try FileManager.default.removeItem( at: url )
    }

    @Test
    func unreadableFile() async throws
    {
        let url = URL( fileURLWithPath: NSTemporaryDirectory(), isDirectory: true ).appending( component: UUID().uuidString ).appendingPathExtension( "fits" )

        try #require( FileManager.default.fileExists( atPath: url.path ) == false )
        try #require( FileManager.default.createFile( atPath: url.path, contents: Data(), attributes: [ .posixPermissions: 0666 ] ) )

        #expect( throws: FITSError.self ) { try FITSFile( url: url ) }

        try FileManager.default.removeItem( at: url )
    }

    @Test
    func emptyData() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: Data() ) }
    }

    @Test
    func data() async throws
    {
        let url  = try #require( TestUtilities.testFiles.first { $0.lastPathComponent == "FOSy19g0309t_c2f.fits" } )
        let file = try FITSFile( url: url )
        let copy = try FITSFile( data: file.data )

        #expect( file.data        == copy.data )
        #expect( file.description == copy.description )
    }

    @Test
    func description() async throws
    {
        let url  = try #require( TestUtilities.testFiles.first { $0.lastPathComponent == "FOSy19g0309t_c2f.fits" } )
        let file = try FITSFile( url: url )

        #expect( file.description.isEmpty == false )
        #expect( file.description         != _typeName( FITSFile.self, qualified: true ) )
    }

    @Test
    func noHeader() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.standardExtensionBlock( includeEndMarker: true, keywords: [] ) ) }
    }

    @Test
    func noSimpleProperty() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "BITPIX", "8" ), ( "END", "" ) ] ) ) }
    }

    @Test
    func invalidSimpleProperty() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "0" ), ( "END", "" ) ] ) ) }
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "F" ), ( "END", "" ) ] ) ) }
    }

    @Test
    func noBitpixProperty() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "END", "" ) ] ) ) }
    }

    @Test
    func invalidBitpixProperty() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "T" ), ( "END", "" ) ] ) ) }
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "0" ), ( "END", "" ) ] ) ) }
    }

    @Test
    func validBitpixProperties() async throws
    {
        let values: [ Int64 ] = [ 8, 16, 32, 64, -32, -64 ]

        try values.forEach
        {
            value in

            let file   = try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "\( value )" ), ( "NAXIS", "0" ), ( "END", "" ) ] ) )
            let header = try #require( file.header )

            #expect( header.properties[ 1 ].name          == "BITPIX", "BITPIX value: \( value )" )
            #expect( header.properties[ 1 ].value.kind    == .integer, "BITPIX value: \( value )" )
            #expect( header.properties[ 1 ].value.integer == value,    "BITPIX value: \( value )" )
        }
    }

    @Test
    func noNaxisProperty() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "END", "" ) ] ) ) }
    }

    @Test
    func invalidNaxisProperty() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "T " ), ( "END", "" ) ] ) ) }
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1 " ), ( "END", "" ) ] ) ) }
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "-1" ), ( "END", "" ) ] ) ) }
    }

    @Test
    func naxisAboveMaximumIsRejected() async throws
    {
        // FITS 4.0 caps NAXIS at 999. A value above that must be rejected by
        // the range check itself, not merely fall through to a missing-NAXISn
        // error, so we assert on the specific "out of range" diagnostic.
        do
        {
            _ = try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1000" ), ( "END", "" ) ] ) )

            Issue.record( "Expected FITSFile to reject NAXIS = 1000" )
        }
        catch let error as FITSError
        {
            let description = error.errorDescription ?? ""

            #expect( description.contains( "NAXIS" ) )
            #expect( description.contains( "out of range" ) )
        }
    }

    @Test
    func invalidNaxisNProperty() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1" ), ( "NAXIS1", "T " ), ( "END", "" ) ] ) ) }
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1" ), ( "NAXIS1", "-1" ), ( "END", "" ) ] ) ) }
    }

    @Test
    func header() async throws
    {
        let file   = try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "0" ), ( "FOOBAR", "42" ), ( "END", "" ) ] ) )
        let header = try #require( file.header )

        #expect( header.kind == .header )

        try #require( header.properties.count == 4 )

        #expect( header.properties[ 0 ].name          == "SIMPLE" )
        #expect( header.properties[ 0 ].value.kind    == .logical )
        #expect( header.properties[ 0 ].value.logical == true )

        #expect( header.properties[ 1 ].name          == "BITPIX" )
        #expect( header.properties[ 1 ].value.kind    == .integer )
        #expect( header.properties[ 1 ].value.integer == 8 )

        #expect( header.properties[ 2 ].name          == "NAXIS" )
        #expect( header.properties[ 2 ].value.kind    == .integer )
        #expect( header.properties[ 2 ].value.integer == 0 )

        #expect( header.properties[ 3 ].name          == "FOOBAR" )
        #expect( header.properties[ 3 ].value.kind    == .integer )
        #expect( header.properties[ 3 ].value.integer == 42 )
    }

    @Test
    func extensions() async throws
    {
        let header     = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] )
        let ext1       = try TestUtilities.headerBlock( keywords: [ ( "XTENSION", "'TABLE   '" ), ( "BITPIX", "8" ), ( "NAXIS", "0" ), ( "PCOUNT", "0" ), ( "GCOUNT", "1" ), ( "FOO", "1" ), ( "END", "" ) ] )
        let ext2       = try TestUtilities.headerBlock( keywords: [ ( "XTENSION", "'IMAGE   '" ), ( "BITPIX", "8" ), ( "NAXIS", "0" ), ( "PCOUNT", "0" ), ( "GCOUNT", "1" ), ( "BAR", "2" ), ( "END", "" ) ] )
        let file       = try FITSFile( data: header + ext1 + ext2 )
        let extensions = file.extensions

        try #require( extensions.count == 2 )

        #expect( extensions[ 0 ].kind                           == .xtension )
        #expect( extensions[ 0 ].properties[ 0 ].name           == "XTENSION" )
        #expect( extensions[ 0 ].properties[ 0 ].value.kind     == .string )
        #expect( extensions[ 0 ].properties[ 0 ].value.string   == "TABLE" )
        #expect( extensions[ 0 ].properties.last?.name          == "FOO" )
        #expect( extensions[ 0 ].properties.last?.value.integer == 1 )

        #expect( extensions[ 1 ].kind                           == .xtension )
        #expect( extensions[ 1 ].properties[ 0 ].name           == "XTENSION" )
        #expect( extensions[ 1 ].properties[ 0 ].value.kind     == .string )
        #expect( extensions[ 1 ].properties[ 0 ].value.string   == "IMAGE" )
        #expect( extensions[ 1 ].properties.last?.name          == "BAR" )
        #expect( extensions[ 1 ].properties.last?.value.integer == 2 )
    }

    @Test
    func validExtensionHeaderIsAccepted() async throws
    {
        let header = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] )
        let ext    = try TestUtilities.headerBlock( keywords: [ ( "XTENSION", "'IMAGE   '" ), ( "BITPIX", "8" ), ( "NAXIS", "0" ), ( "PCOUNT", "0" ), ( "GCOUNT", "1" ), ( "END", "" ) ] )

        #expect( throws: Never.self ) { try FITSFile( data: header + ext ) }
    }

    @Test
    func extensionMissingMandatoryKeywordsIsRejected() async throws
    {
        // XTENSION present but BITPIX / NAXIS / PCOUNT / GCOUNT are missing.
        let header = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] )
        let ext    = try TestUtilities.headerBlock( keywords: [ ( "XTENSION", "'IMAGE   '" ), ( "FOO", "1" ), ( "END", "" ) ] )

        #expect( throws: FITSError.self ) { try FITSFile( data: header + ext ) }
    }

    @Test
    func extensionMissingPcountGcountIsRejected() async throws
    {
        let header = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] )
        let ext    = try TestUtilities.headerBlock( keywords: [ ( "XTENSION", "'IMAGE   '" ), ( "BITPIX", "8" ), ( "NAXIS", "0" ), ( "END", "" ) ] )

        #expect( throws: FITSError.self ) { try FITSFile( data: header + ext ) }
    }

    @Test
    func extensionWithMisorderedPcountGcountIsRejected() async throws
    {
        // GCOUNT before PCOUNT violates the mandatory keyword order.
        let header = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] )
        let ext    = try TestUtilities.headerBlock( keywords: [ ( "XTENSION", "'IMAGE   '" ), ( "BITPIX", "8" ), ( "NAXIS", "0" ), ( "GCOUNT", "1" ), ( "PCOUNT", "0" ), ( "END", "" ) ] )

        #expect( throws: FITSError.self ) { try FITSFile( data: header + ext ) }
    }

    @Test
    func extensionWithNonStringXtensionIsRejected() async throws
    {
        let header = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] )
        let ext    = try TestUtilities.headerBlock( keywords: [ ( "XTENSION", "8" ), ( "BITPIX", "8" ), ( "NAXIS", "0" ), ( "PCOUNT", "0" ), ( "GCOUNT", "1" ), ( "END", "" ) ] )

        #expect( throws: FITSError.self ) { try FITSFile( data: header + ext ) }
    }

    @Test
    func dataLengthMismatchIsRejectedWhenStrict() async throws
    {
        // Header declares a 2880-byte array (|BITPIX| 8 x NAXIS1 2880) but no
        // data blocks follow it.
        let header = try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1" ), ( "NAXIS1", "2880" ), ( "END", "" ) ] )

        #expect( throws: FITSError.self ) { try FITSFile( data: header, options: .strict ) }
    }

    @Test
    func dataLengthMismatchIsToleratedWhenLenient() async throws
    {
        let header = try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1" ), ( "NAXIS1", "2880" ), ( "END", "" ) ] )

        #expect( throws: Never.self ) { try FITSFile( data: header, options: .lenient ) }
    }

    @Test
    func correctlySizedDataIsAccepted() async throws
    {
        // |BITPIX| 8 x NAXIS1 2880 = 2880 bytes = exactly one 2880-byte block.
        let header = try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1" ), ( "NAXIS1", "2880" ), ( "END", "" ) ] )
        let data   = TestUtilities.dataBlock( fill: 0x00 )

        #expect( throws: Never.self ) { try FITSFile( data: header + data, options: .strict ) }
    }

    @Test
    func naxisProductOverflowThrowsInsteadOfTrapping() async throws
    {
        // NAXIS1 x NAXIS2 overflows Int64. A corrupt geometry must surface a
        // thrown FITSError rather than trapping the process. The overflow is a
        // hard structural error, so it is rejected even under .lenient.
        let header = try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "2" ), ( "NAXIS1", "\( Int64.max )" ), ( "NAXIS2", "2" ), ( "END", "" ) ] )

        #expect( throws: FITSError.self ) { try FITSFile( data: header, options: .lenient ) }
    }

    @Test
    func extensionPcountProductOverflowThrowsInsteadOfTrapping() async throws
    {
        // PCOUNT + product overflows Int64 on the extension data-size path.
        let header = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] )
        let ext    = try TestUtilities.headerBlock( keywords: [ ( "XTENSION", "'IMAGE   '" ), ( "BITPIX", "8" ), ( "NAXIS", "1" ), ( "NAXIS1", "1" ), ( "PCOUNT", "\( Int64.max )" ), ( "GCOUNT", "1" ), ( "END", "" ) ] )

        #expect( throws: FITSError.self ) { try FITSFile( data: header + ext, options: .lenient ) }
    }

    @Test
    func bitpixByteCountOverflowThrowsInsteadOfTrapping() async throws
    {
        // The element count fits in Int64, but (|BITPIX| / 8) x elements does
        // not: BITPIX 64 means 8 bytes per element and NAXIS1 near Int64.max / 4.
        let header = try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "64" ), ( "NAXIS", "1" ), ( "NAXIS1", "\( Int64.max / 4 )" ), ( "END", "" ) ] )

        #expect( throws: FITSError.self ) { try FITSFile( data: header, options: .lenient ) }
    }

    @Test
    func trailingPaddingAfterEndIsNotData() async throws
    {
        // A NAXIS = 0 primary (no data) followed by an extra all-spaces block
        // must parse cleanly in strict mode and not become a phantom data
        // section, while still round-tripping the padding bytes.
        let header  = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] )
        let padding = TestUtilities.dataBlock( fill: 0x20 )
        let file    = try FITSFile( data: header + padding, options: .strict )

        #expect( file.sections.count == 1 )
        #expect( file.sections.allSatisfy { $0.kind != .data } )
        #expect( file.extensions.isEmpty )
        #expect( file.data == header + padding )
    }

    @Test
    func dataBlockResemblingExtensionIsConsumedAsData() async throws
    {
        // The header declares one 2880-byte data block. The data block is ASCII
        // and begins with "XTENSION=", which the old sentinel/ASCII heuristic
        // would mis-split into a new extension. Geometry must consume it as data.
        let header = try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1" ), ( "NAXIS1", "2880" ), ( "END", "" ) ] )
        let data   = try TestUtilities.headerBlock( fields: [ "XTENSION= 'TABLE    '" ] )
        let file   = try FITSFile( data: header + data, options: .strict )

        try #require( file.sections.count == 2 )

        #expect( file.sections[ 0 ].kind == .header )
        #expect( file.sections[ 1 ].kind == .data )
        #expect( file.extensions.isEmpty )
    }

    @Test
    func multiHduFileSplitsByGeometry() async throws
    {
        // A primary HDU with a data block, then an extension HDU with its own
        // data block. The first data block is itself ASCII and begins with an
        // "XTENSION=" sentinel, so only geometry — not the sentinel — can place
        // the boundaries correctly.
        let header = try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1" ), ( "NAXIS1", "2880" ), ( "END", "" ) ] )
        let data1  = try TestUtilities.headerBlock( fields: [ "XTENSION= 'TABLE    '" ] )
        let ext    = try TestUtilities.headerBlock( keywords: [ ( "XTENSION", "'IMAGE   '" ), ( "BITPIX", "8" ), ( "NAXIS", "1" ), ( "NAXIS1", "2880" ), ( "PCOUNT", "0" ), ( "GCOUNT", "1" ), ( "END", "" ) ] )
        let data2  = TestUtilities.dataBlock( fill: 0x00 )
        let file   = try FITSFile( data: header + data1 + ext + data2, options: .strict )

        try #require( file.sections.count == 4 )

        #expect( file.sections[ 0 ].kind == .header )
        #expect( file.sections[ 1 ].kind == .data )
        #expect( file.sections[ 2 ].kind == .xtension )
        #expect( file.sections[ 3 ].kind == .data )
        #expect( file.extensions.count == 1 )

        #expect( file.data == header + data1 + ext + data2 )
    }

    @Test
    func truncatedMultiBlockDataIsRejectedWhenStrictToleratedWhenLenient() async throws
    {
        // |BITPIX| 8 x NAXIS1 5760 = 5760 bytes = two 2880-byte blocks, but only
        // one data block follows.
        let header = try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1" ), ( "NAXIS1", "5760" ), ( "END", "" ) ] )
        let data   = TestUtilities.dataBlock( fill: 0x00 )

        #expect( throws: FITSError.self ) { try FITSFile( data: header + data, options: .strict ) }
        #expect( throws: Never.self     ) { try FITSFile( data: header + data, options: .lenient ) }
    }

    @Test
    func absurdlyLargeButNonOverflowingGeometryIsRejected() async throws
    {
        // 10^18 bytes does not overflow Int64 but is far beyond any real file
        // and must be rejected by the sanity ceiling rather than producing a
        // meaningless multi-exabyte expected size.
        let header = try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1" ), ( "NAXIS1", "1000000000000000000" ), ( "END", "" ) ] )

        #expect( throws: FITSError.self ) { try FITSFile( data: header, options: .lenient ) }
    }
}
