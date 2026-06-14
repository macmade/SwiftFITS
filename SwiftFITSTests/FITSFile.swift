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

            #expect( header.properties[ 1 ].name == "BITPIX", "BITPIX value: \( value )" )
            #expect( header.properties[ 1 ].kind == .integer, "BITPIX value: \( value )" )
            #expect( header.properties[ 1 ].value.integer == value, "BITPIX value: \( value )" )
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

        #expect( header.properties[ 0 ].name == "SIMPLE" )
        #expect( header.properties[ 0 ].kind == .logical )
        #expect( header.properties[ 0 ].value.logical == true )

        #expect( header.properties[ 1 ].name == "BITPIX" )
        #expect( header.properties[ 1 ].kind == .integer )
        #expect( header.properties[ 1 ].value.integer == 8 )

        #expect( header.properties[ 2 ].name == "NAXIS" )
        #expect( header.properties[ 2 ].kind == .integer )
        #expect( header.properties[ 2 ].value.integer == 0 )

        #expect( header.properties[ 3 ].name == "FOOBAR" )
        #expect( header.properties[ 3 ].kind == .integer )
        #expect( header.properties[ 3 ].value.integer == 42 )
    }

    @Test
    func extensions() async throws
    {
        let header     = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] )
        let ext1       = try TestUtilities.headerBlock( keywords: [ ( "XTENSION", "'TABLE   '" ), ( "FOO", "1" ), ( "END", "" ) ] )
        let ext2       = try TestUtilities.headerBlock( keywords: [ ( "XTENSION", "'IMAGE   '" ), ( "BAR", "2" ), ( "END", "" ) ] )
        let file       = try FITSFile( data: header + ext1 + ext2 )
        let extensions = file.extensions

        try #require( extensions.count == 2 )

        #expect( extensions[ 0 ].kind                             == .xtension )
        #expect( extensions[ 0 ].properties.count                 == 2 )
        #expect( extensions[ 0 ].properties[ 0 ].name             == "XTENSION" )
        #expect( extensions[ 0 ].properties[ 0 ].kind             == .string )
        #expect( extensions[ 0 ].properties[ 0 ].value.string == "TABLE" )
        #expect( extensions[ 0 ].properties[ 1 ].name             == "FOO" )
        #expect( extensions[ 0 ].properties[ 1 ].kind             == .integer )
        #expect( extensions[ 0 ].properties[ 1 ].value.integer  == 1 )

        #expect( extensions[ 1 ].kind                             == .xtension )
        #expect( extensions[ 1 ].properties.count                 == 2 )
        #expect( extensions[ 1 ].properties[ 0 ].name             == "XTENSION" )
        #expect( extensions[ 1 ].properties[ 0 ].kind             == .string )
        #expect( extensions[ 1 ].properties[ 0 ].value.string == "IMAGE" )
        #expect( extensions[ 1 ].properties[ 1 ].name             == "BAR" )
        #expect( extensions[ 1 ].properties[ 1 ].kind             == .integer )
        #expect( extensions[ 1 ].properties[ 1 ].value.integer  == 2 )
    }
}
