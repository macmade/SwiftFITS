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

struct Test_FITSSerializationOptions
{
    @Test
    func rawValueRoundTrips() async throws
    {
        [ 0, 1, 42 ].forEach
        {
            #expect( FITSSerializationOptions( rawValue: $0 ).rawValue == $0 )
        }
    }

    @Test
    func strictAndLenientPresetsExist() async throws
    {
        // The two presets must be usable option-set values, round-tripping
        // through their raw bitmask like any other option set.
        let strict:  FITSSerializationOptions = .strict
        let lenient: FITSSerializationOptions = .lenient

        #expect( strict  == FITSSerializationOptions( rawValue: strict.rawValue ) )
        #expect( lenient == FITSSerializationOptions( rawValue: lenient.rawValue ) )
    }

    @Test
    func optionSetAlgebra() async throws
    {
        var options: FITSSerializationOptions = []

        options.formUnion( .strict )

        #expect( options.contains( .strict ) )
    }
}
