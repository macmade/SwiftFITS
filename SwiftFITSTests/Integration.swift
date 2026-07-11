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

/// End-to-end tests spanning the whole read/write pipeline: constructing files
/// from scratch, editing parsed files, managing extensions, and writing to disk,
/// across the ``FITSFile``/``FITSSection``/``FITSProperty`` layers together.
struct Test_Integration
{
    @Test
    func imageFileFullLifecycle() async throws
    {
        // Build a 2x2 8-bit image, tag it, write it to disk, read it back, reshape
        // it to a 3x3 16-bit image with new pixels, write again, and confirm the
        // whole round-trip — geometry, the preserved keyword and the new data.
        let url = URL( fileURLWithPath: NSTemporaryDirectory(), isDirectory: true ).appending( component: UUID().uuidString ).appendingPathExtension( "fits" )

        defer { try? FileManager.default.removeItem( at: url ) }

        let file = try FITSFile( bitpix: 8, axes: [ 2, 2 ], data: Data( [ 1, 2, 3, 4 ] ) )

        try file.header?.setProperty( FITSProperty( name: "OBJECT", string: "M42", options: .strict ) )
        try file.write( to: url, options: .strict )

        let reread = try FITSFile( url: url, options: .strict )

        #expect( reread.header?[ "OBJECT" ]?.value == .string( "M42" ) )
        #expect( reread.header?.naxis              == 2 )

        try reread.setPrimaryData( bitpix: 16, axes: [ 3, 3 ], data: Data( repeating: 0x7F, count: 18 ) )
        try reread.write( to: url, options: .strict )

        let final   = try FITSFile( url: url, options: .strict )
        let segment = try #require( final.sections.first { $0.kind == .data } )

        #expect( final.header?.bitpix              == 16 )
        #expect( final.header?.naxis( 1 )          == 3 )
        #expect( final.header?.naxis( 2 )          == 3 )
        #expect( final.header?[ "OBJECT" ]?.value  == .string( "M42" ) )
        #expect( try segment.data.prefix( 18 )     == Data( repeating: 0x7F, count: 18 ) )
    }

    @Test
    func tableExtensionFileRoundTrips() async throws
    {
        // A NAXIS=0 primary plus a TABLE extension (a 4x2 character array) built
        // from scratch, serialized and re-parsed with its EXTEND declaration.
        let file = try FITSFile( bitpix: 8, axes: [] )

        try file.appendExtension( type: "TABLE", bitpix: 8, axes: [ 4, 2 ], data: Data( "ABCDEFGH".utf8 ) )

        let reparsed = try FITSFile( data: try file.serializedData( options: .strict ), options: .strict )
        let ext      = try #require( reparsed.extensions.first )
        let segment  = try #require( reparsed.sections.last )

        #expect( reparsed.extensions.count           == 1 )
        #expect( reparsed.header?[ "EXTEND" ]?.value == .logical( true ) )
        #expect( ext[ "XTENSION" ]?.value            == .string( "TABLE" ) )
        #expect( ext.naxis                           == 2 )
        #expect( ext.naxis( 1 )                      == 4 )
        #expect( ext.naxis( 2 )                      == 2 )
        #expect( try segment.data.prefix( 8 )        == Data( "ABCDEFGH".utf8 ) )
    }

    @Test
    func multiHduEditPreservesUntouchedSectionsByteForByte() async throws
    {
        // Build a primary plus two extensions, parse the bytes back so every
        // section is clean, then edit only the first extension's header: the edit
        // lands while the primary and the second extension stay byte-for-byte.
        let builder = try FITSFile( bitpix: 8, axes: [ 2, 2 ], data: Data( [ 1, 2, 3, 4 ] ) )

        try builder.appendExtension( type: "IMAGE", bitpix: 8, axes: [ 2, 2 ], data: Data( [ 5, 6, 7, 8 ] ) )
        try builder.appendExtension( type: "IMAGE", bitpix: 8, axes: [ 3 ],    data: Data( [ 9, 10, 11 ] ) )

        let file = try FITSFile( data: try builder.serializedData( options: .strict ), options: .strict )

        let primaryBefore   = try #require( try file.header?.data )
        let secondExtBefore = try #require( try file.extensions.last?.data )

        try file.extensions.first?.setProperty( FITSProperty( name: "EXTNAME", string: "SCI", options: .strict ) )

        let reparsed = try FITSFile( data: try file.serializedData( options: .strict ), options: .strict )

        #expect( reparsed.extensions.first?[ "EXTNAME" ]?.value == .string( "SCI" ) )
        #expect( try reparsed.header?.data                      == primaryBefore )
        #expect( try reparsed.extensions.last?.data             == secondExtBefore )
    }

    @Test
    func buildRemoveAndReorderExtensions() async throws
    {
        // Build three extensions with distinct dimensionalities, drop the middle
        // one, move the last to the front, and confirm the surviving order after a
        // write/re-parse round-trip.
        let file = try FITSFile( bitpix: 8, axes: [] )

        try file.appendExtension( type: "IMAGE", bitpix: 8, axes: [ 1 ],       data: Data( [ 1 ] ) )
        try file.appendExtension( type: "IMAGE", bitpix: 8, axes: [ 2, 1 ],    data: Data( [ 2, 3 ] ) )
        try file.appendExtension( type: "IMAGE", bitpix: 8, axes: [ 3, 1, 1 ], data: Data( [ 4, 5, 6 ] ) )

        try #require( file.extensions.count == 3 )

        try file.removeExtension( at: 1 )
        try file.moveExtension( from: 1, to: 0 )

        let reparsed = try FITSFile( data: try file.serializedData( options: .strict ), options: .strict )

        try #require( reparsed.extensions.count == 2 )

        #expect( reparsed.extensions[ 0 ].naxis == 3 )
        #expect( reparsed.extensions[ 1 ].naxis == 1 )
    }

    @Test
    func strictVsLenientSerializationAndErrorPaths() async throws
    {
        // A geometry/data-size mismatch is rejected by strict serialization and
        // tolerated by lenient.
        let mismatched = try FITSFile( bitpix: 8, axes: [ 5760 ], data: Data( repeating: 0x00, count: 100 ) )

        #expect( throws: FITSError.self ) { try mismatched.serializedData( options: .strict ) }
        #expect( throws: Never.self     ) { try mismatched.serializedData( options: .lenient ) }

        // Writing to an unwritable location surfaces cannotWriteFile.
        let file = try FITSFile( bitpix: 8, axes: [] )
        let url  = URL( fileURLWithPath: "/no/such/directory/\( UUID().uuidString ).fits" )

        #expect( throws: FITSError.self ) { try file.write( to: url, options: .strict ) }

        // Out-of-range extension operations throw rather than trap.
        #expect( throws: FITSError.self ) { try file.removeExtension( at: 0 ) }
        #expect( throws: FITSError.self ) { try file.moveExtension( from: 0, to: 0 ) }
    }
}
