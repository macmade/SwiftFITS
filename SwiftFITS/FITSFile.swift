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

public class FITSFile: CustomStringConvertible
{
    public static let blockSize = 2880

    public private( set ) var sections: [ FITSSection ]

    public convenience init( url: URL, options: FITSParsingOptions = .lenient ) throws
    {
        var isDir: ObjCBool = false

        guard FileManager.default.fileExists( atPath: url.path, isDirectory: &isDir ), isDir.boolValue == false
        else
        {
            throw FITSError.invalidFileURL( url: url )
        }

        do
        {
            let data = try Data( contentsOf: url, options: .mappedIfSafe )

            try self.init( data: data, options: options )
        }
        catch let error as FITSError
        {
            throw error
        }
        catch
        {
            throw FITSError.cannotReadFile( url: url )
        }
    }

    public init( data: Data, options: FITSParsingOptions = .lenient ) throws
    {
        guard data.isEmpty == false
        else
        {
            throw FITSError.dataError( reason: "Data is empty" )
        }

        let blocks = try data.chunked( by: FITSFile.blockSize ).map
        {
            try FITSBlock( data: $0 )
        }

        let sections = try blocks.reduce( into: [ FITSSection ]() )
        {
            if $1.hasExtensionMarker
            {
                $0.append( try FITSSection( kind: .xtension, block: $1 ) )
            }
            else if let last = $0.last
            {
                if last.canAppendData
                {
                    try last.append( block: $1 )
                }
                else
                {
                    $0.append( try FITSSection( kind: .data, block: $1 ) )
                }
            }
            else
            {
                $0.append( try FITSSection( kind: .header, block: $1 ) )
            }
        }

        try sections.forEach
        {
            try $0.finalize( options: options )
        }

        guard let header = sections.first
        else
        {
            throw FITSError.invalidFileData( reason: "No sections" )
        }

        guard header.kind == .header
        else
        {
            throw FITSError.invalidFileData( reason: "First section is not a header" )
        }

        try FITSFile.validateMandatoryKeywords( in: header.properties, isExtension: false )

        try sections.filter { $0.kind == .xtension }.forEach
        {
            try FITSFile.validateMandatoryKeywords( in: $0.properties, isExtension: true )
        }

        try sections.enumerated().forEach
        {
            index, section in

            guard section.kind == .header || section.kind == .xtension
            else
            {
                return
            }

            let expected = FITSFile.expectedDataSize( for: section.properties, isExtension: section.kind == .xtension )
            let next     = index + 1 < sections.count ? sections[ index + 1 ] : nil
            let actual   = next?.kind == .data ? ( next?.dataSize ?? 0 ) : 0

            if actual != expected, options.contains( .allowDataLengthMismatch ) == false
            {
                throw FITSError.invalidFileData( reason: "Data length mismatch: expected \( expected ) bytes but found \( actual )" )
            }
        }

        self.sections = sections
    }

    // Validates the mandatory keywords (name, order and type) common to a
    // primary header (Table 7) or a conforming extension (Table 10) per
    // FITS 4.0 §4.4.1: SIMPLE/XTENSION, BITPIX, NAXIS, NAXISn, then PCOUNT and
    // GCOUNT for extensions. Type-specific keywords (IMAGE/TABLE/BINTABLE, §7)
    // are not enforced here.
    private class func validateMandatoryKeywords( in properties: [ FITSProperty ], isExtension: Bool ) throws
    {
        if isExtension
        {
            try FITSFile.validate( index: 0, in: properties, name: "XTENSION", kind: .string )
        }
        else
        {
            try FITSFile.validate( index: 0, in: properties, name: "SIMPLE", kind: .logical )
            {
                guard case .logical( true ) = $0
                else
                {
                    throw FITSError.invalidFileData( reason: "Invalid value for SIMPLE property" )
                }
            }
        }

        try FITSFile.validate( index: 1, in: properties, name: "BITPIX", kind: .integer )
        {
            guard case .integer( let value ) = $0, [ 8, 16, 32, 64, -32, -64 ].contains( value )
            else
            {
                throw FITSError.invalidFileData( reason: "Invalid value for BITPIX property" )
            }
        }

        try FITSFile.validate( index: 2, in: properties, name: "NAXIS",  kind: .integer )

        let naxis = properties[ 2 ].value.integer ?? 0

        // FITS 4.0 (§4.4.1) caps NAXIS at 999.
        guard naxis >= 0, naxis <= 999
        else
        {
            throw FITSError.invalidFileData( reason: "NAXIS value out of range: \( naxis ) (expected 0...999)" )
        }

        try ( 0 ..< naxis ).forEach
        {
            index in try FITSFile.validate( index: Int( index + 3 ), in: properties, name: "NAXIS\( index + 1 )", kind: .integer )
            {
                guard case .integer( let value ) = $0, value >= 0
                else
                {
                    throw FITSError.invalidFileData( reason: "Invalid value for NAXIS\( index + 1 ) property" )
                }
            }
        }

        if isExtension
        {
            // PCOUNT and GCOUNT immediately follow the NAXISn set.
            try FITSFile.validate( index: Int( naxis ) + 3, in: properties, name: "PCOUNT", kind: .integer )
            try FITSFile.validate( index: Int( naxis ) + 4, in: properties, name: "GCOUNT", kind: .integer )
        }
    }

    // Expected data-segment size in bytes (padded to a whole number of 2880-byte
    // blocks) for a header/extension, per the FITS 4.0 data-size formulas:
    // primary (Eq. 1) |BITPIX|/8 x Pi NAXISn; extension (Eq. 2) additionally
    // x GCOUNT x ( PCOUNT + Pi NAXISn ). NAXIS = 0 means no data follow.
    private class func expectedDataSize( for properties: [ FITSProperty ], isExtension: Bool ) -> Int
    {
        let bitpix = properties.first { $0.name == "BITPIX" }?.value.integer ?? 0
        let naxis  = properties.first { $0.name == "NAXIS"  }?.value.integer ?? 0

        guard naxis > 0
        else
        {
            return 0
        }

        let product = ( 1 ... naxis ).reduce( Int64( 1 ) )
        {
            result, n in result * ( properties.first { $0.name == "NAXIS\( n )" }?.value.integer ?? 0 )
        }

        let elements: Int64

        if isExtension
        {
            let pcount = properties.first { $0.name == "PCOUNT" }?.value.integer ?? 0
            let gcount = properties.first { $0.name == "GCOUNT" }?.value.integer ?? 1

            elements = gcount * ( pcount + product )
        }
        else
        {
            elements = product
        }

        let bytes  = Int( ( abs( bitpix ) / 8 ) * elements )
        let blocks = ( bytes + FITSFile.blockSize - 1 ) / FITSFile.blockSize

        return blocks * FITSFile.blockSize
    }

    public class func validate( index: Int, in properties: [ FITSProperty ], name: String, kind: FITSValue.Kind, validate: ( ( FITSValue ) throws -> Void )? = nil ) throws
    {
        guard properties.count > index
        else
        {
            throw FITSError.invalidFileData( reason: "Missing property \( name ) expected at index \( index )" )
        }

        guard properties[ index ].name == name
        else
        {
            throw FITSError.invalidFileData( reason: "Missing property \( name ) expected at index \( index ) - Found \( properties[ index ].name ) instead" )
        }

        guard properties[ index ].value.kind == kind
        else
        {
            throw FITSError.invalidFileData( reason: "Invalid type for property \( name ) at index \( index ) - Expected \( kind ) but found \( properties[ index ].value.kind )" )
        }

        try validate?( properties[ index ].value )
    }

    public var data: Data
    {
        let sections = self.sections.map { $0.data }
        let size     = sections.reduce( 0 ) { $0 + $1.count }
        var data     = Data( capacity: size )

        sections.forEach
        {
            data.append( $0 )
        }

        return data
    }

    public var header: FITSSection?
    {
        return self.sections.first
    }

    public var extensions: [ FITSSection ]
    {
        return self.sections.filter { $0.kind == .xtension }
    }

    public var description: String
    {
        """
        FITSFile
        {
            Sections:
            [
        \( self.sections.map { $0.description( indent: 2 ) }.joined( separator: "\n" ) )
            ]
        }
        """
    }
}
