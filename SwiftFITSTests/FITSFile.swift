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

struct Test_FITSFile
{
    @Test
    func serializationConstants() async throws
    {
        // The card size and keyword-field length fixed by the FITS standard,
        // exposed as named constants so both the read and write paths share them.
        #expect( FITSFile.cardSize      == 80 )
        #expect( FITSFile.keywordLength == 8 )
    }

    @Test
    func parseAllTestFiles() async throws
    {
        try TestUtilities.testFiles.forEach
        {
            let _ = try FITSFile( url: $0, options: .lenient )
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
            let file = try FITSFile( data: data, options: .lenient )

            #expect( try file.data == data, "Round-trip mismatch for \( url.lastPathComponent )" )
        }
    }

    @Test
    func invalidURL() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( url: URL( fileURLWithPath: "/foo/bar.fits" ), options: .lenient ) }
    }

    @Test
    func emptyFile() async throws
    {
        let url = URL( fileURLWithPath: NSTemporaryDirectory(), isDirectory: true ).appending( component: UUID().uuidString ).appendingPathExtension( "fits" )

        try #require( FileManager.default.fileExists( atPath: url.path ) == false )
        try #require( FileManager.default.createFile( atPath: url.path, contents: Data(), attributes: nil ) )

        #expect( throws: FITSError.self ) { try FITSFile( url: url, options: .lenient ) }

        try FileManager.default.removeItem( at: url )
    }

    @Test
    func unreadableFile() async throws
    {
        let url = URL( fileURLWithPath: NSTemporaryDirectory(), isDirectory: true ).appending( component: UUID().uuidString ).appendingPathExtension( "fits" )

        try #require( FileManager.default.fileExists( atPath: url.path ) == false )
        try #require( FileManager.default.createFile( atPath: url.path, contents: Data(), attributes: [ .posixPermissions: 0666 ] ) )

        #expect( throws: FITSError.self ) { try FITSFile( url: url, options: .lenient ) }

        try FileManager.default.removeItem( at: url )
    }

    @Test
    func emptyData() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: Data(), options: .lenient ) }
    }

    @Test
    func missingFileThrowsInvalidFileURL() async throws
    {
        do
        {
            _ = try FITSFile( url: URL( fileURLWithPath: "/no/such/file.fits" ), options: .lenient )

            Issue.record( "Expected FITSFile to reject a missing file" )
        }
        catch let error as FITSError
        {
            guard case .invalidFileURL = error
            else
            {
                Issue.record( "Expected invalidFileURL but got \( error )" )

                return
            }
        }
    }

    @Test
    func directoryThrowsInvalidFileURL() async throws
    {
        let directory = URL( fileURLWithPath: NSTemporaryDirectory(), isDirectory: true )

        do
        {
            _ = try FITSFile( url: directory, options: .lenient )

            Issue.record( "Expected FITSFile to reject a directory" )
        }
        catch let error as FITSError
        {
            guard case .invalidFileURL = error
            else
            {
                Issue.record( "Expected invalidFileURL but got \( error )" )

                return
            }
        }
    }

    @Test
    func unreadableFileThrowsCannotReadFile() async throws
    {
        let url = URL( fileURLWithPath: NSTemporaryDirectory(), isDirectory: true ).appending( component: UUID().uuidString ).appendingPathExtension( "fits" )

        try #require( FileManager.default.createFile( atPath: url.path, contents: Data( [ 0x00 ] ), attributes: [ .posixPermissions: 0o000 ] ) )

        defer { try? FileManager.default.removeItem( at: url ) }

        // A process running as root can read 0000 files, so this mapping is only
        // observable for an unprivileged user; skip the assertion otherwise.
        guard FileManager.default.isReadableFile( atPath: url.path ) == false
        else
        {
            return
        }

        do
        {
            _ = try FITSFile( url: url, options: .lenient )

            Issue.record( "Expected FITSFile to reject an unreadable file" )
        }
        catch let error as FITSError
        {
            guard case .cannotReadFile = error
            else
            {
                Issue.record( "Expected cannotReadFile but got \( error )" )

                return
            }
        }
    }

    @Test
    func data() async throws
    {
        let url  = try #require( TestUtilities.testFiles.first { $0.lastPathComponent == "FOSy19g0309t_c2f.fits" } )
        let file = try FITSFile( url: url, options: .lenient )
        let copy = try FITSFile( data: file.data, options: .lenient )

        #expect( try file.data    == copy.data )
        #expect( file.description == copy.description )
    }

    @Test
    func description() async throws
    {
        let url  = try #require( TestUtilities.testFiles.first { $0.lastPathComponent == "FOSy19g0309t_c2f.fits" } )
        let file = try FITSFile( url: url, options: .lenient )

        #expect( file.description.isEmpty == false )
        #expect( file.description         != _typeName( FITSFile.self, qualified: true ) )
    }

    @Test
    func endMarkerInSecondHeaderBlock() async throws
    {
        // A header that legitimately spans two blocks: the END marker lives in
        // the second block. The whole header must be read as a single section.
        let block1 = try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "0" ), ( "FOO", "1" ) ] )
        let block2 = try TestUtilities.headerBlock( keywords: [ ( "BAR", "1" ), ( "END", "" ) ] )
        let file   = try FITSFile( data: block1 + block2, options: .lenient )

        #expect( file.sections.count == 1 )
    }

    @Test
    func endPrefixKeywordDoesNotEndHeaderEarly() async throws
    {
        // The last non-blank record of the first block is a custom keyword
        // beginning with "END"; the real END marker lives in the second block.
        // The header must span both blocks rather than stopping early.
        let block1 = try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "0" ), ( "ENDED", "1" ) ] )
        let block2 = try TestUtilities.headerBlock( keywords: [ ( "FOO", "1" ), ( "END", "" ) ] )
        let file   = try FITSFile( data: block1 + block2, options: .lenient )

        #expect( file.sections.count == 1 )
    }

    @Test
    func duplicateGeometryKeywordResolvesFirstWins() async throws
    {
        // Two NAXIS1 records: the first implies one data block (2880 bytes),
        // the second would imply two (5760 bytes). Under strict parsing a data
        // length mismatch is rejected, so supplying exactly one data block
        // parses only if the geometry resolves the first occurrence.
        let header = try TestUtilities.headerBlock(
            keywords:
            [
                ( "SIMPLE", "T"    ),
                ( "BITPIX", "8"    ),
                ( "NAXIS",  "1"    ),
                ( "NAXIS1", "2880" ),
                ( "NAXIS1", "5760" ),
                ( "END",    ""     ),
            ]
        )
        let data = TestUtilities.dataBlock( fill: 0xFF )
        let file = try FITSFile( data: header + data, options: .strict )

        #expect( file.sections.count == 2 )
        #expect( file.sections[ 1 ].dataSize == FITSFile.blockSize )
    }

    @Test
    func noHeader() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.standardExtensionBlock( includeEndMarker: true, keywords: [] ), options: .lenient ) }
    }

    @Test
    func noSimpleProperty() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "BITPIX", "8" ), ( "END", "" ) ] ), options: .lenient ) }
    }

    @Test
    func invalidSimpleProperty() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "0" ), ( "END", "" ) ] ), options: .lenient ) }
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "F" ), ( "END", "" ) ] ), options: .lenient ) }
    }

    @Test
    func noBitpixProperty() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "END", "" ) ] ), options: .lenient ) }
    }

    @Test
    func invalidBitpixProperty() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "T" ), ( "END", "" ) ] ), options: .lenient ) }
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "0" ), ( "END", "" ) ] ), options: .lenient ) }
    }

    @Test
    func validBitpixProperties() async throws
    {
        let values: [ Int64 ] = [ 8, 16, 32, 64, -32, -64 ]

        try values.forEach
        {
            value in

            let file   = try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "\( value )" ), ( "NAXIS", "0" ), ( "END", "" ) ] ), options: .lenient )
            let header = try #require( file.header )

            #expect( header.properties[ 1 ].name          == "BITPIX", "BITPIX value: \( value )" )
            #expect( header.properties[ 1 ].value.kind    == .integer, "BITPIX value: \( value )" )
            #expect( header.properties[ 1 ].value.integer == value,    "BITPIX value: \( value )" )
        }
    }

    @Test
    func noNaxisProperty() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "END", "" ) ] ), options: .lenient ) }
    }

    @Test
    func invalidNaxisProperty() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "T " ), ( "END", "" ) ] ), options: .lenient ) }
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1 " ), ( "END", "" ) ] ), options: .lenient ) }
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "-1" ), ( "END", "" ) ] ), options: .lenient ) }
    }

    @Test
    func naxisAboveMaximumIsRejected() async throws
    {
        // FITS 4.0 caps NAXIS at 999. A value above that must be rejected by
        // the range check itself, not merely fall through to a missing-NAXISn
        // error, so we assert on the specific "out of range" diagnostic.
        do
        {
            _ = try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1000" ), ( "END", "" ) ] ), options: .lenient )

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
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1" ), ( "NAXIS1", "T " ), ( "END", "" ) ] ), options: .lenient ) }
        #expect( throws: FITSError.self ) { try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1" ), ( "NAXIS1", "-1" ), ( "END", "" ) ] ), options: .lenient ) }
    }

    @Test
    func header() async throws
    {
        let file   = try FITSFile( data: try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "0" ), ( "FOOBAR", "42" ), ( "END", "" ) ] ), options: .lenient )
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
        let file       = try FITSFile( data: header + ext1 + ext2, options: .lenient )
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

        #expect( throws: Never.self ) { try FITSFile( data: header + ext, options: .lenient ) }
    }

    @Test
    func extensionMissingMandatoryKeywordsIsRejected() async throws
    {
        // XTENSION present but BITPIX / NAXIS / PCOUNT / GCOUNT are missing.
        let header = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] )
        let ext    = try TestUtilities.headerBlock( keywords: [ ( "XTENSION", "'IMAGE   '" ), ( "FOO", "1" ), ( "END", "" ) ] )

        #expect( throws: FITSError.self ) { try FITSFile( data: header + ext, options: .lenient ) }
    }

    @Test
    func extensionMissingPcountGcountIsRejected() async throws
    {
        let header = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] )
        let ext    = try TestUtilities.headerBlock( keywords: [ ( "XTENSION", "'IMAGE   '" ), ( "BITPIX", "8" ), ( "NAXIS", "0" ), ( "END", "" ) ] )

        #expect( throws: FITSError.self ) { try FITSFile( data: header + ext, options: .lenient ) }
    }

    @Test
    func extensionWithMisorderedPcountGcountIsRejected() async throws
    {
        // GCOUNT before PCOUNT violates the mandatory keyword order.
        let header = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] )
        let ext    = try TestUtilities.headerBlock( keywords: [ ( "XTENSION", "'IMAGE   '" ), ( "BITPIX", "8" ), ( "NAXIS", "0" ), ( "GCOUNT", "1" ), ( "PCOUNT", "0" ), ( "END", "" ) ] )

        #expect( throws: FITSError.self ) { try FITSFile( data: header + ext, options: .lenient ) }
    }

    @Test
    func extensionWithNonStringXtensionIsRejected() async throws
    {
        let header = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] )
        let ext    = try TestUtilities.headerBlock( keywords: [ ( "XTENSION", "8" ), ( "BITPIX", "8" ), ( "NAXIS", "0" ), ( "PCOUNT", "0" ), ( "GCOUNT", "1" ), ( "END", "" ) ] )

        #expect( throws: FITSError.self ) { try FITSFile( data: header + ext, options: .lenient ) }
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
    func orphanedContinueFileRoundTrips() async throws
    {
        // A file whose header carries an orphaned CONTINUE (predecessor is not a
        // &-terminated string) parses under .lenient (allowOrphanedContinue) and
        // round-trips byte-for-byte, the record's bytes being retained.
        let block = try TestUtilities.headerBlock(
            keywords:
            [
                ( "SIMPLE",   "T"         ),
                ( "BITPIX",   "8"         ),
                ( "NAXIS",    "0"         ),
                ( "FOOBAR",   "'hello'"   ),
                ( "CONTINUE", "', world'" ),
                ( "END",      ""          ),
            ]
        )
        let file = try FITSFile( data: block, options: .lenient )

        #expect( file.header?.properties.contains { $0.name == "CONTINUE" } == true )
        #expect( try file.data == block )
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
    func nonAsciiDataSegmentParsesWithoutClassification() async throws
    {
        // The header fixes the data role via geometry, so a non-ASCII data block
        // must parse without being rejected or classified as a header.
        let header = try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1" ), ( "NAXIS1", "2880" ), ( "END", "" ) ] )
        let data   = TestUtilities.dataBlock( fill: 0xFF )
        let file   = try FITSFile( data: header + data, options: .strict )

        try #require( file.sections.count == 2 )

        #expect( file.sections[ 1 ].kind == .data )
        #expect( try file.data == header + data )
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
        #expect( try file.data == header + padding )
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

        #expect( try file.data == header + data1 + ext + data2 )
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
    func largeBlockCountExpectedSizeIsNotNarrowed() async throws
    {
        // |BITPIX| 8 x NAXIS1 10^13 implies a block count above Int32.max yet a
        // byte size well below maxDataSize. The expected size must be carried in
        // Int64 end-to-end: narrowing the block count to a 32-bit Int would wrap
        // and report a wrong size. Strict mode with no data surfaces the value in
        // the mismatch diagnostic, where we assert it is reported intact.
        let header = try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1" ), ( "NAXIS1", "10000000000000" ), ( "END", "" ) ] )

        do
        {
            _ = try FITSFile( data: header, options: .strict )

            Issue.record( "Expected FITSFile to reject the truncated large-geometry data" )
        }
        catch let error as FITSError
        {
            // 10^13 bytes padded up to a whole number of 2880-byte blocks.
            #expect( error.errorDescription?.contains( "10000000002240" ) == true )
        }
    }

    @Test
    func endNotLastRecordTerminatesSectionConsistently() async throws
    {
        // A primary header whose END is followed by a non-blank record (dropped
        // under lenient), then a separate extension. The first block's END must
        // terminate the header section so the extension is parsed on its own,
        // rather than being swallowed into the primary header by accumulating
        // past an END that is not the last non-blank record.
        let header = try TestUtilities.headerBlock( fields: [ "SIMPLE  = T", "BITPIX  = 8", "NAXIS   = 0", "END", "JUNK    = 1" ] )
        let ext    = try TestUtilities.headerBlock( keywords: [ ( "XTENSION", "'IMAGE   '" ), ( "BITPIX", "8" ), ( "NAXIS", "0" ), ( "PCOUNT", "0" ), ( "GCOUNT", "1" ), ( "END", "" ) ] )
        let file   = try FITSFile( data: header + ext, options: .lenient )

        #expect( file.sections.count   == 2 )
        #expect( file.extensions.count == 1 )
    }

    @Test
    func trailingPartialBlockIsRejectedWhenStrictPaddedWhenLenient() async throws
    {
        // A valid NAXIS = 0 header followed by 100 trailing bytes that do not
        // fill a block. Strict parsing rejects the whole file before any
        // leniency applies; lenient (allowTrailingPartialBlock) pads the
        // partial block out to full size, preserving the original bytes and
        // zero-filling the remainder, so it round-trips as the padded form.
        let header  = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] )
        let partial = Data( repeating: 0x20, count: 100 )
        let data    = header + partial

        #expect( throws: FITSError.self ) { try FITSFile( data: data, options: .strict ) }

        let file = try FITSFile( data: data, options: .lenient )

        #expect( file.sections.count == 1 )
        #expect( try file.data.count == FITSFile.blockSize * 2 )
        #expect( try file.data       == header + partial + Data( repeating: 0x00, count: FITSFile.blockSize - 100 ) )
    }

    @Test
    func nulPaddedHeaderIsRejectedWhenStrictParsedWhenLenient() async throws
    {
        // A header whose custom keyword is NUL-padded ("FOO" + NUL fill in the
        // 8-byte keyword field) and whose block tail after END is NUL-filled
        // rather than space-filled. Strict parsing rejects the NUL bytes;
        // lenient (allowNulPadding) treats NUL as padding, so the keyword is
        // recovered, END is detected, and the single header section terminates.
        func record( _ string: String ) -> Data
        {
            string.padding( toLength: 80, withPad: " ", startingAt: 0 ).data( using: .ascii )!
        }

        var keyword = Data( "FOO".utf8 )
        keyword.append( contentsOf: [ UInt8 ]( repeating: 0x00, count: 5 ) ) // NUL-pad the 8-byte keyword field
        keyword.append( Data( "= 1".utf8 ) )
        keyword.append( contentsOf: [ UInt8 ]( repeating: 0x20, count: 80 - keyword.count ) )

        var block = record( "SIMPLE  = T" ) + record( "BITPIX  = 8" ) + record( "NAXIS   = 0" ) + keyword + record( "END" )
        block.append( contentsOf: [ UInt8 ]( repeating: 0x00, count: FITSFile.blockSize - block.count ) ) // NUL tail padding

        #expect( throws: FITSError.self ) { try FITSFile( data: block, options: .strict ) }

        let file = try FITSFile( data: block, options: .lenient )

        #expect( file.sections.count == 1 )
        #expect( file.header?.properties.last?.name          == "FOO" )
        #expect( file.header?.properties.last?.value.integer == 1 )
        #expect( try file.data == block )
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

    @Test
    func serializedDataRoundTripsAllTestFiles() async throws
    {
        // A clean file serialized with the same leniency it was parsed with
        // reproduces its original bytes exactly.
        try TestUtilities.testFiles.forEach
        {
            let data = try Data( contentsOf: $0 )
            let file = try FITSFile( data: data, options: .lenient )

            #expect( try file.serializedData( options: .lenient ) == data, "Round-trip mismatch for \( $0.lastPathComponent )" )
        }
    }

    @Test
    func writeThenRereadReproducesBytes() async throws
    {
        let bytes = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [ ( "FOO", "42" ) ] )
        let file  = try FITSFile( data: bytes, options: .strict )
        let url   = URL( fileURLWithPath: NSTemporaryDirectory(), isDirectory: true ).appending( component: UUID().uuidString ).appendingPathExtension( "fits" )

        defer { try? FileManager.default.removeItem( at: url ) }

        try file.write( to: url, options: .strict )

        let reread   = try Data( contentsOf: url )
        let reparsed = try FITSFile( data: reread, options: .strict )

        #expect( reread == bytes )
        #expect( try reparsed.data == bytes )
    }

    @Test
    func strictSerializationRejectsDataSizeMismatch() async throws
    {
        // A header declares two 2880-byte data blocks but only one follows; the
        // file parses under lenient (allowDataLengthMismatch). Strict
        // serialization must reject the geometry/data mismatch, lenient tolerate it.
        let header = try TestUtilities.headerBlock( keywords: [ ( "SIMPLE", "T" ), ( "BITPIX", "8" ), ( "NAXIS", "1" ), ( "NAXIS1", "5760" ), ( "END", "" ) ] )
        let data   = TestUtilities.dataBlock( fill: 0x00 )
        let file   = try FITSFile( data: header + data, options: .lenient )

        #expect( throws: FITSError.self ) { try file.serializedData( options: .strict ) }
        #expect( throws: Never.self     ) { try file.serializedData( options: .lenient ) }
    }

    @Test
    func writeToUnwritableURLThrowsCannotWriteFile() async throws
    {
        let bytes = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] )
        let file  = try FITSFile( data: bytes, options: .strict )
        let url   = URL( fileURLWithPath: "/no/such/directory/\( UUID().uuidString ).fits" )

        do
        {
            try file.write( to: url, options: .strict )

            Issue.record( "Expected write to an unwritable location to throw" )
        }
        catch let error as FITSError
        {
            guard case .cannotWriteFile = error
            else
            {
                Issue.record( "Expected cannotWriteFile but got \( error )" )

                return
            }
        }
    }

    @Test
    func buildsPrimaryHDUFromScratchAndRoundTrips() async throws
    {
        // A 3x2 unsigned-byte image built from scratch: BITPIX 8, two axes, and
        // exactly six bytes of pixel data.
        let pixels = Data( [ 1, 2, 3, 4, 5, 6 ] )
        let file   = try FITSFile( bitpix: 8, axes: [ 3, 2 ], data: pixels )
        let bytes  = try file.serializedData( options: .strict )

        // One header block and one data block.
        try #require( bytes.count == FITSFile.blockSize * 2 )

        let reparsed = try FITSFile( data: bytes, options: .strict )
        let header   = try #require( reparsed.header )

        #expect( reparsed.sections.count   == 2 )
        #expect( header[ "SIMPLE" ]?.value == .logical( true ) )
        #expect( header.bitpix             == 8 )
        #expect( header.naxis              == 2 )
        #expect( header.naxis( 1 )         == 3 )
        #expect( header.naxis( 2 )         == 2 )

        let segment = try #require( reparsed.sections.first { $0.kind == .data } )

        #expect( try segment.data.prefix( 6 ) == pixels )
    }

    @Test
    func buildsHeadersOnlyPrimaryWithNoData() async throws
    {
        // NAXIS 0 (no axes, no data) yields a single header block.
        let file  = try FITSFile( bitpix: 8, axes: [] )
        let bytes = try file.serializedData( options: .strict )

        #expect( bytes.count == FITSFile.blockSize )

        let reparsed = try FITSFile( data: bytes, options: .strict )

        #expect( reparsed.sections.count == 1 )
        #expect( reparsed.header?.naxis  == 0 )
    }

    @Test
    func appendsExtensionAndAutoAddsExtendKeyword() async throws
    {
        let file = try FITSFile( bitpix: 8, axes: [ 2, 2 ], data: Data( [ 1, 2, 3, 4 ] ) )

        try file.appendExtension( type: "IMAGE", bitpix: 8, axes: [ 2, 2 ], data: Data( [ 5, 6, 7, 8 ] ) )

        // Appending an extension declares EXTEND = T in the primary header.
        #expect( file.header?[ "EXTEND" ]?.value == .logical( true ) )

        let bytes    = try file.serializedData( options: .strict )
        let reparsed = try FITSFile( data: bytes, options: .strict )

        try #require( reparsed.extensions.count == 1 )

        let extension0 = try #require( reparsed.extensions.first )

        #expect( reparsed.header?[ "EXTEND" ]?.value == .logical( true ) )
        #expect( extension0[ "XTENSION" ]?.value     == .string( "IMAGE" ) )
        #expect( extension0.bitpix                    == 8 )
        #expect( extension0.naxis                     == 2 )
        #expect( extension0[ "PCOUNT" ]?.value        == .integer( 0 ) )
        #expect( extension0[ "GCOUNT" ]?.value        == .integer( 1 ) )
    }

    @Test
    func writesFromScratchFileToDiskAndReadsBack() async throws
    {
        let pixels = Data( [ 10, 20, 30, 40 ] )
        let file   = try FITSFile( bitpix: 8, axes: [ 2, 2 ], data: pixels )
        let url    = URL( fileURLWithPath: NSTemporaryDirectory(), isDirectory: true ).appending( component: UUID().uuidString ).appendingPathExtension( "fits" )

        defer { try? FileManager.default.removeItem( at: url ) }

        try file.write( to: url, options: .strict )

        let reread  = try FITSFile( url: url, options: .strict )
        let segment = try #require( reread.sections.first { $0.kind == .data } )

        #expect( reread.header?.naxis         == 2 )
        #expect( try segment.data.prefix( 4 ) == pixels )
    }

    @Test
    func fromScratchFileDefersDataSizeValidationToWrite() async throws
    {
        // Construction assembles the keywords without validating; a data segment
        // too small for the geometry is caught only on write (strict), and
        // tolerated under lenient.
        let file = try FITSFile( bitpix: 8, axes: [ 5760 ], data: Data( repeating: 0x00, count: 100 ) )

        #expect( throws: FITSError.self ) { try file.serializedData( options: .strict ) }
        #expect( throws: Never.self     ) { try file.serializedData( options: .lenient ) }
    }

    @Test
    func appendExtensionWithPathologicalNaxisDoesNotTrap() async throws
    {
        // A deliberately-absurd primary NAXIS must not overflow-trap the EXTEND
        // insertion-index computation. The keyword is placed safely (appended)
        // and the broken geometry is left for write-time validation to reject.
        let file    = try FITSFile( bitpix: 8, axes: [ 2, 2 ], data: Data( [ 1, 2, 3, 4 ] ) )
        let primary = try #require( file.header )

        try primary.setProperty( try FITSProperty( name: "NAXIS", integer: .max, options: .strict ) )

        #expect( throws: Never.self ) { try file.appendExtension( type: "IMAGE", bitpix: 8, axes: [ 2, 2 ], data: Data( [ 5, 6, 7, 8 ] ) ) }
        #expect( file.header?[ "EXTEND" ]?.value == .logical( true ) )
    }

    @Test
    func naxisZeroPrimaryWithDataIsRejectedWithClearMessage() async throws
    {
        // A NAXIS = 0 primary declares no data, so attaching a data segment is
        // rejected on write with a message pointing at the zero-data geometry
        // rather than a bare "unexpected section".
        let file = try FITSFile( bitpix: 8, axes: [], data: Data( [ 1, 2, 3, 4 ] ) )

        do
        {
            _ = try file.serializedData( options: .strict )

            Issue.record( "Expected a NAXIS = 0 primary carrying data to be rejected" )
        }
        catch let error as FITSError
        {
            let description = error.errorDescription ?? ""

            #expect( description.contains( "data segment" ) )
            #expect( description.contains( "NAXIS" ) )
        }
    }

    @Test
    func editingOnlyOneSectionKeepsOthersByteForByte() async throws
    {
        // Build a two-HDU file and parse it back so every section is clean.
        // Editing a keyword in the primary must re-render only the primary; the
        // extension (header and data) is re-emitted from its retained bytes,
        // byte-for-byte.
        let builder = try FITSFile( bitpix: 8, axes: [ 2, 2 ], data: Data( [ 1, 2, 3, 4 ] ) )

        try builder.appendExtension( type: "IMAGE", bitpix: 8, axes: [ 2, 2 ], data: Data( [ 5, 6, 7, 8 ] ) )

        let original = try builder.serializedData( options: .strict )
        let file     = try FITSFile( data: original, options: .strict )

        // Capture the extension's bytes before editing anything.
        let extensionBefore = try #require( try file.extensions.first?.data )

        try file.header?.setProperty( FITSProperty( name: "OBJECT", string: "M42", options: .strict ) )

        let rewritten = try file.serializedData( options: .strict )
        let reparsed  = try FITSFile( data: rewritten, options: .strict )

        // The edit landed on the primary, and the untouched extension is identical.
        #expect( reparsed.header?[ "OBJECT" ]?.value == .string( "M42" ) )
        #expect( try reparsed.extensions.first?.data == extensionBefore )
    }

    @Test
    func replacingDataPayloadOfParsedSectionRerendersOnlyThatSegment() async throws
    {
        // A parsed data segment whose payload is replaced re-renders with the new
        // bytes while the header stays byte-for-byte identical.
        let builder = try FITSFile( bitpix: 8, axes: [ 2, 2 ], data: Data( [ 1, 2, 3, 4 ] ) )
        let file    = try FITSFile( data: try builder.serializedData( options: .strict ), options: .strict )
        let header  = try #require( file.header )

        let headerBefore = try header.data
        let segment      = try #require( file.sections.first { $0.kind == .data } )

        try segment.setDataPayload( Data( [ 9, 8, 7, 6 ] ) )

        let reparsed = try FITSFile( data: try file.serializedData( options: .strict ), options: .strict )

        #expect( try reparsed.header?.data                         == headerBefore )
        #expect( try reparsed.sections.last?.data.prefix( 4 )      == Data( [ 9, 8, 7, 6 ] ) )
    }

    @Test
    func removeExtensionDropsHeaderAndData() async throws
    {
        let file = try FITSFile( bitpix: 8, axes: [] )

        try file.appendExtension( type: "IMAGE", bitpix: 8, axes: [ 2, 2 ], data: Data( [ 1, 2, 3, 4 ] ) )
        try file.appendExtension( type: "IMAGE", bitpix: 8, axes: [ 3 ],    data: Data( [ 7, 8, 9 ] ) )

        try #require( file.extensions.count == 2 )

        try file.removeExtension( at: 0 )

        #expect( file.extensions.count == 1 )
        #expect( throws: FITSError.self ) { try file.removeExtension( at: 5 ) }

        let reparsed = try FITSFile( data: try file.serializedData( options: .strict ), options: .strict )

        #expect( reparsed.extensions.count      == 1 )
        #expect( reparsed.extensions.first?.naxis == 1 )
    }

    @Test
    func moveExtensionReordersHDUs() async throws
    {
        let file = try FITSFile( bitpix: 8, axes: [] )

        try file.appendExtension( type: "IMAGE", bitpix: 8, axes: [ 2, 2 ], data: Data( [ 1, 2, 3, 4 ] ) )
        try file.appendExtension( type: "IMAGE", bitpix: 8, axes: [ 3 ],    data: Data( [ 7, 8, 9 ] ) )

        try file.moveExtension( from: 1, to: 0 )

        #expect( throws: FITSError.self ) { try file.moveExtension( from: 0, to: 9 ) }

        let reparsed = try FITSFile( data: try file.serializedData( options: .strict ), options: .strict )

        try #require( reparsed.extensions.count == 2 )

        #expect( reparsed.extensions[ 0 ].naxis == 1 )
        #expect( reparsed.extensions[ 1 ].naxis == 2 )
    }

    @Test
    func setPrimaryDataUpdatesGeometryAndPayloadTogether() async throws
    {
        // Parse a 2x2 image, then re-shape the primary to a 3x3 16-bit image; the
        // mandatory geometry keywords and the data segment update together and
        // round-trip.
        let builder = try FITSFile( bitpix: 8, axes: [ 2, 2 ], data: Data( [ 1, 2, 3, 4 ] ) )
        let file    = try FITSFile( data: try builder.serializedData( options: .strict ), options: .strict )

        try file.setPrimaryData( bitpix: 16, axes: [ 3, 3 ], data: Data( repeating: 0xAB, count: 18 ) )

        let reparsed = try FITSFile( data: try file.serializedData( options: .strict ), options: .strict )
        let header   = try #require( reparsed.header )

        #expect( header.bitpix     == 16 )
        #expect( header.naxis      == 2 )
        #expect( header.naxis( 1 ) == 3 )
        #expect( header.naxis( 2 ) == 3 )

        let segment = try #require( reparsed.sections.first { $0.kind == .data } )

        #expect( try segment.data.prefix( 18 ) == Data( repeating: 0xAB, count: 18 ) )
    }

    @Test
    func setExtensionDataUpdatesGeometryAndPreservesPcountGcount() async throws
    {
        let builder = try FITSFile( bitpix: 8, axes: [] )

        try builder.appendExtension( type: "IMAGE", bitpix: 8, axes: [ 2, 2 ], data: Data( [ 1, 2, 3, 4 ] ) )

        let file = try FITSFile( data: try builder.serializedData( options: .strict ), options: .strict )

        try file.setExtensionData( at: 0, bitpix: 16, axes: [ 3 ], data: Data( repeating: 0xCD, count: 6 ) )

        let reparsed   = try FITSFile( data: try file.serializedData( options: .strict ), options: .strict )
        let extension0 = try #require( reparsed.extensions.first )

        #expect( extension0.bitpix             == 16 )
        #expect( extension0.naxis              == 1 )
        #expect( extension0.naxis( 1 )         == 3 )
        #expect( extension0[ "PCOUNT" ]?.value == .integer( 0 ) )
        #expect( extension0[ "GCOUNT" ]?.value == .integer( 1 ) )

        let segment = try #require( reparsed.sections.last )

        #expect( segment.kind                   == .data )
        #expect( try segment.data.prefix( 6 )   == Data( repeating: 0xCD, count: 6 ) )
    }

    @Test
    func extensionEditsWithPathologicalIndexDoNotTrap() async throws
    {
        // A pathological Int index must throw rather than overflow-trapping the
        // bounds check that positions the operation.
        let file = try FITSFile( bitpix: 8, axes: [] )

        try file.appendExtension( type: "IMAGE", bitpix: 8, axes: [ 2, 2 ], data: Data( [ 1, 2, 3, 4 ] ) )

        #expect( throws: FITSError.self ) { try file.removeExtension( at: .max ) }
        #expect( throws: FITSError.self ) { try file.setExtensionData( at: .max, bitpix: 8, axes: [ 1 ], data: Data( [ 0 ] ) ) }
    }
}
