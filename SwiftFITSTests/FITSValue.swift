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

struct Test_FITSValue
{
    @Test
    func accessorReturnsPayloadForMatchingCase() async throws
    {
        #expect( FITSValue.logical( true ).logical == true )
        #expect( FITSValue.integer( 42 ).integer   == 42 )
        #expect( FITSValue.float( 42.5 ).float     == 42.5 )
        #expect( FITSValue.string( "hi" ).string   == "hi" )
    }

    @Test
    func accessorReturnsNilForNonMatchingCase() async throws
    {
        #expect( FITSValue.integer( 42 ).logical  == nil )
        #expect( FITSValue.integer( 42 ).float    == nil )
        #expect( FITSValue.integer( 42 ).string   == nil )
        #expect( FITSValue.string( "hi" ).integer == nil )
        #expect( FITSValue.undefined.integer      == nil )
        #expect( FITSValue.unknown( "x" ).string  == nil )
    }

    @Test
    func kindDerivesFromCase() async throws
    {
        #expect( FITSValue.logical( true ).kind == .logical )
        #expect( FITSValue.integer( 42 ).kind   == .integer )
        #expect( FITSValue.float( 42.5 ).kind   == .float )
        #expect( FITSValue.string( "hi" ).kind  == .string )
        #expect( FITSValue.undefined.kind       == .undefined )
        #expect( FITSValue.unknown( "x" ).kind  == .unknown )
    }

    @Test
    func kindDescription() async throws
    {
        #expect( FITSValue.Kind.logical.description   == "Logical" )
        #expect( FITSValue.Kind.integer.description   == "Integer" )
        #expect( FITSValue.Kind.float.description     == "Float" )
        #expect( FITSValue.Kind.string.description    == "String" )
        #expect( FITSValue.Kind.undefined.description == "Undefined" )
        #expect( FITSValue.Kind.unknown.description   == "Unknown" )
    }

    @Test
    func equality() async throws
    {
        #expect( FITSValue.integer( 42 )  == .integer( 42 ) )
        #expect( FITSValue.integer( 42 )  != .integer( 43 ) )
        #expect( FITSValue.integer( 42 )  != .float( 42 ) )
        #expect( FITSValue.undefined      == .undefined )
        #expect( FITSValue.unknown( "a" ) != .unknown( "b" ) )
    }
}
