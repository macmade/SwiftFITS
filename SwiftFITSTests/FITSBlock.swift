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

struct Test_FITSBlock
{
    @Test
    func containsOnlyASCII() async throws
    {
        let block1 = try FITSBlock( data: Data( repeating: 0x20, count: FITSFile.blockSize ), options: .strict )
        let block2 = try FITSBlock( data: Data( repeating: 0xFF, count: FITSFile.blockSize ), options: .strict )

        #expect( block1.containsOnlyASCII == true )
        #expect( block2.containsOnlyASCII == false )
    }

    @Test
    func hasEndMarker() async throws
    {
        // The block reports whether it contains an END record. A leading space
        // makes the keyword not END (block2). An END that is not the last
        // non-blank record still counts (block3): the first END terminates the
        // section, matching how the section locates END.
        let data1  = try TestUtilities.headerBlock( fields: [ ( "FOO     = 1" ), ( "BAR     = 1" ), ( "END        " ) ] )
        let data2  = try TestUtilities.headerBlock( fields: [ ( "FOO     = 1" ), ( "BAR     = 1" ), ( " END       " ) ] )
        let data3  = try TestUtilities.headerBlock( fields: [ ( "FOO     = 1" ), ( "END        " ), ( "BAR     = 1" ) ] )
        let block1 = try FITSBlock( data: data1, options: .strict )
        let block2 = try FITSBlock( data: data2, options: .strict )
        let block3 = try FITSBlock( data: data3, options: .strict )

        #expect( block1.hasEndMarker == true )
        #expect( block2.hasEndMarker == false )
        #expect( block3.hasEndMarker == true )
    }

    @Test
    func hasEndMarkerMatchesExactlyNotByPrefix() async throws
    {
        // A custom keyword that merely begins with "END" must not be mistaken
        // for the END marker.
        let data1  = try TestUtilities.headerBlock( fields: [ ( "FOO     = 1" ), ( "ENDED   = 1" ) ] )
        let data2  = try TestUtilities.headerBlock( fields: [ ( "FOO     = 1" ), ( "ENDTIME = 1" ) ] )
        let block1 = try FITSBlock( data: data1, options: .strict )
        let block2 = try FITSBlock( data: data2, options: .strict )

        #expect( block1.hasEndMarker == false )
        #expect( block2.hasEndMarker == false )
    }

    @Test
    func hasEndMarkerTreatsNulAsPaddingOnlyWhenAllowed() async throws
    {
        // A NUL-padded END record: under the space-only padding "END\0…" does
        // not trim to "END", so the marker is missed, but allowNulPadding folds
        // NUL into the padding so it is recognized.
        func record( _ string: String ) -> Data
        {
            string.padding( toLength: 80, withPad: " ", startingAt: 0 ).data( using: .ascii )!
        }

        var end = Data( "END".utf8 )
        end.append( contentsOf: [ UInt8 ]( repeating: 0x00, count: 80 - end.count ) ) // NUL-pad the END record

        var data = record( "FOO     = 1" ) + end
        data.append( contentsOf: [ UInt8 ]( repeating: 0x20, count: FITSFile.blockSize - data.count ) )

        #expect( try FITSBlock( data: data, options: .strict ).hasEndMarker              == false )
        #expect( try FITSBlock( data: data, options: [ .allowNulPadding ] ).hasEndMarker == true )
    }

    @Test
    func hasExtensionMarker() async throws
    {
        let data1  = try TestUtilities.headerBlock( fields: [ ( "XTENSION  'TABLE    ' " ), ( "FOO     = 1          " ), ( "BAR     = 1" ) ] )
        let data2  = try TestUtilities.headerBlock( fields: [ ( "XTENSION= 'TABLE    ' " ), ( "FOO     = 1          " ), ( "BAR     = 1" ) ] )
        let data3  = try TestUtilities.headerBlock( fields: [ ( " XTENSION= 'TABLE    '" ), ( "FOO     = 1          " ), ( "BAR     = 1" ) ] )
        let data4  = try TestUtilities.headerBlock( fields: [ ( "FOO     = 1           " ), ( "XTENSION= 'TABLE    '" ), ( "BAR     = 1" ) ] )
        let block1 = try FITSBlock( data: data1, options: .strict )
        let block2 = try FITSBlock( data: data2, options: .strict )
        let block3 = try FITSBlock( data: data3, options: .strict )
        let block4 = try FITSBlock( data: data4, options: .strict )

        #expect( block1.hasExtensionMarker == false )
        #expect( block2.hasExtensionMarker == true )
        #expect( block3.hasExtensionMarker == false )
        #expect( block4.hasExtensionMarker == false )
    }

    @Test
    func hasEndMarkerAndExtensionMarker() async throws
    {
        let data  = try TestUtilities.standardExtensionBlock( includeEndMarker: true, keywords: [ ( "FOO", "1" ), ( "BAR", "1" ) ] )
        let block = try FITSBlock( data: data, options: .strict )

        #expect( block.hasEndMarker       == true )
        #expect( block.hasExtensionMarker == true )
    }

    @Test
    func binary() async throws
    {
        var data                       = try TestUtilities.standardHeaderBlock( includeEndMarker: false, keywords: [ ( "FOO", "1" ), ( "BAR", "1" ) ] )
        data[ FITSFile.blockSize - 1 ] = 0xFF
        let block                      = try FITSBlock( data: data, options: .strict )

        #expect( block.containsOnlyASCII == false )
    }

    @Test
    func binaryAndEndMarker() async throws
    {
        var data                       = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [ ( "FOO", "1" ), ( "BAR", "1" ) ] )
        data[ FITSFile.blockSize - 1 ] = 0xFF
        let block                      = try FITSBlock( data: data, options: .strict )

        #expect( block.containsOnlyASCII == false )
        #expect( block.hasEndMarker      == false )
    }

    @Test
    func binaryAndExtensionMarker() async throws
    {
        var data                       = try TestUtilities.standardExtensionBlock( includeEndMarker: true, keywords: [ ( "FOO", "1" ), ( "BAR", "1" ) ] )
        data[ FITSFile.blockSize - 1 ] = 0xFF
        let block                      = try FITSBlock( data: data, options: .strict )

        #expect( block.containsOnlyASCII  == false )
        #expect( block.hasExtensionMarker == false )
    }

    @Test
    func initEmptyData() async throws
    {
        #expect( throws: FITSError.self ) { try FITSBlock( data: Data(), options: .strict ) }
    }

    @Test
    func initWrongSizeThrowsInvalidBlockSize() async throws
    {
        // A wrong-sized buffer must be rejected with the specific
        // invalidBlockSize error, ahead of any byte-level scan of the block.
        do
        {
            _ = try FITSBlock( data: Data( repeating: 0x20, count: FITSFile.blockSize + 1 ), options: .strict )

            Issue.record( "Expected FITSBlock to reject a wrong-sized buffer" )
        }
        catch let error as FITSError
        {
            guard case .invalidBlockSize = error
            else
            {
                Issue.record( "Expected invalidBlockSize but got \( error )" )

                return
            }
        }
    }

    @Test
    func description() async throws
    {
        let block = try FITSBlock( data: Data( repeating: 0x20, count: FITSFile.blockSize ), options: .strict )

        #expect( block.description.isEmpty == false )
        #expect( block.description         != _typeName( FITSBlock.self, qualified: true ) )
    }
}
