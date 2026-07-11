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

    @Test
    func nanFloatValuesAreEqual() async throws
    {
        // Two NaN float values compare equal so that diffing two headers does
        // not report a spurious change, departing from IEEE 754 NaN semantics.
        #expect( FITSValue.float( .nan ) == .float( .nan ) )

        // Ordinary finite values keep normal equality.
        #expect( FITSValue.float( 42.5 ) == .float( 42.5 ) )
        #expect( FITSValue.float( 42.5 ) != .float( 42.0 ) )
        #expect( FITSValue.float( .nan ) != .float( 42.5 ) )
    }

    @Test
    func nanFloatValuesHashEqual() async throws
    {
        // hash(into:) must be consistent with the NaN-equal ==: two equal NaN
        // values must land in the same bucket.
        #expect( FITSValue.float( .nan ).hashValue == FITSValue.float( .nan ).hashValue )
    }

    @Test
    func distinctValuesHashDistinctly() async throws
    {
        // Representative values across every case must not collapse to a single
        // bucket (not a strict Hashable guarantee, but a sanity check that the
        // case discriminator participates in the hash).
        let values: [ FITSValue ] = [ .logical( true ), .integer( 1 ), .float( 1.0 ), .string( "x" ), .undefined, .unknown( "y" ) ]
        let hashes                = Set( values.map { $0.hashValue } )

        #expect( hashes.count == values.count )
    }

    @Test
    func valueSetRoundTrips() async throws
    {
        // Duplicate integers and equal NaNs collapse; three distinct members
        // remain, and membership honors the custom NaN-equal equality.
        let set: Set< FITSValue > = [ .integer( 1 ), .integer( 1 ), .float( .nan ), .float( .nan ), .string( "a" ) ]

        #expect( set.count == 3 )
        #expect( set.contains( .integer( 1 ) ) )
        #expect( set.contains( .float( .nan ) ) )
        #expect( set.contains( .string( "a" ) ) )
    }

    @Test
    func valueTypesAreSendable() async throws
    {
        // Compile-time assertion: the parsed value/error value types are
        // Sendable. (Reference-type containers remain non-Sendable.)
        func requireSendable< T: Sendable >( _: T.Type ) {}

        requireSendable( FITSValue.self )
        requireSendable( FITSValue.Kind.self )
        requireSendable( FITSSection.Kind.self )
        requireSendable( FITSError.self )
    }

    @Test
    func serializesLogical() async throws
    {
        #expect( try FITSValue.logical( true ).serialized()  == "T" )
        #expect( try FITSValue.logical( false ).serialized() == "F" )
    }

    @Test
    func serializesInteger() async throws
    {
        #expect( try FITSValue.integer( 42 ).serialized() == "42" )
        #expect( try FITSValue.integer( -7 ).serialized() == "-7" )
        #expect( try FITSValue.integer( 0 ).serialized()  == "0" )
    }

    @Test
    func serializesFloat() async throws
    {
        // Shortest round-trippable decimal, with the exponent letter uppercased
        // to the FITS-required "E".
        #expect( try FITSValue.float( 3.14 ).serialized()    == "3.14" )
        #expect( try FITSValue.float( -0.5 ).serialized()    == "-0.5" )
        #expect( try FITSValue.float( 2.0 ).serialized()     == "2.0" )
        #expect( try FITSValue.float( 1.5e-10 ).serialized() == "1.5E-10" )
        #expect( try FITSValue.float( 1e20 ).serialized()    == "1E+20" )
    }

    @Test
    func serializesNonFiniteFloatThrows() async throws
    {
        // FITS has no standard literal for the IEEE special values, and the
        // parser never yields them as a float, so rendering one is an error.
        #expect( throws: FITSError.self ) { try FITSValue.float( .infinity ).serialized() }
        #expect( throws: FITSError.self ) { try FITSValue.float( -.infinity ).serialized() }
        #expect( throws: FITSError.self ) { try FITSValue.float( .nan ).serialized() }
    }

    @Test
    func serializesString() async throws
    {
        // Minimal free-format literal: single-quoted, with internal quotes
        // doubled. Null and empty strings keep their distinct representations.
        #expect( try FITSValue.string( "M42" ).serialized()    == "'M42'" )
        #expect( try FITSValue.string( "O'HARA" ).serialized() == "'O''HARA'" )
        #expect( try FITSValue.string( "" ).serialized()       == "''" )
        #expect( try FITSValue.string( " " ).serialized()      == "' '" )
    }

    @Test
    func serializesUndefined() async throws
    {
        #expect( try FITSValue.undefined.serialized() == "" )
    }

    @Test
    func serializesUnknown() async throws
    {
        // An unknown value renders its retained literal verbatim.
        #expect( try FITSValue.unknown( "0xFF" ).serialized() == "0xFF" )
    }

    @Test
    func valueRoundTrips() async throws
    {
        // Parse -> render -> parse must reproduce an equal value for every case.
        let values: [ FITSValue ] =
        [
            .logical( true ),
            .logical( false ),
            .integer( 42 ),
            .integer( -7 ),
            .integer( 0 ),
            .float( 3.14 ),
            .float( -0.5 ),
            .float( 2.0 ),
            .float( 1.5e-10 ),
            .string( "M42" ),
            .string( "O'HARA" ),
            .string( "" ),
            .string( " " ),
            .undefined,
            .unknown( "0xFF" ),
        ]

        try values.forEach
        {
            value in

            let rendered = try value.serialized()
            let reparsed = try Test_FITSValue.parseValue( literal: rendered )

            #expect( reparsed == value, "Round-trip mismatch for \( value )" )
        }
    }

    /// Parses a value literal by embedding it in a minimal keyword record and
    /// reading it back through ``FITSProperty``.
    ///
    /// - Parameter literal: The value literal, as produced by
    ///   ``FITSValue/serialized()``.
    /// - Returns: The parsed value.
    /// - Throws: Any ``FITSError`` raised while parsing the record.
    private static func parseValue( literal: String ) throws -> FITSValue
    {
        let card = "TEST    = \( literal )".padding( toLength: FITSFile.cardSize, withPad: " ", startingAt: 0 )

        return try FITSProperty( string: card, options: .strict ).value
    }
}
