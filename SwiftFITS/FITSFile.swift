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

/// A parsed FITS (Flexible Image Transport System) file.
///
/// Parsing splits the input into fixed-size blocks, groups them into
/// ``FITSSection`` units (a primary header, optional extensions, and their
/// data segments), then validates the mandatory keywords and the data-segment
/// sizes against the declared geometry. ``FITSParsingOptions`` controls how
/// strictly noncompliant input is treated.
///
/// A file holds mutable section state and composes ``FITSBlock``, whose flags
/// cache lazily on read, so even concurrent reads of a fully-parsed file race:
/// it is not thread-safe and not `Sendable`.
public class FITSFile: CustomStringConvertible
{
    /// The size, in bytes, of a single FITS block. Fixed by the standard at 2880.
    public static let blockSize = 2880

    /// The size, in bytes, of a single FITS header record (card). Fixed by the
    /// standard at 80.
    public static let cardSize = 80

    /// The length, in bytes, of the keyword-name field at the start of a header
    /// record. Fixed by the standard at 8.
    public static let keywordLength = 8

    /// The width, in bytes, of the fixed-format value field (bytes 11–30), in
    /// which scalar values are right-justified per FITS 4.0 §4.2.
    public static let fixedValueFieldWidth = 20

    /// An upper bound, in bytes, on a single data segment.
    ///
    /// A geometry implying a larger segment is rejected as corrupt rather than
    /// yielding a meaningless multi-exabyte expected size. The ceiling sits far
    /// above any real FITS file (≈9 PB) yet safely within `Int64`, so the size
    /// math can never overflow once a value passes it.
    public static let maxDataSize = Int64( 1 ) << 53

    /// The file's sections, in file order. The first is always the primary header.
    public private( set ) var sections: [ FITSSection ]

    /// Reads and parses a FITS file from a file URL.
    ///
    /// - Parameters:
    ///   - url: The location of the file to read.
    ///   - options: The parsing options to apply.
    /// - Throws: ``FITSError/invalidFileURL(url:)`` if the URL is missing or a
    ///   directory, ``FITSError/cannotReadFile(url:)`` if the contents cannot
    ///   be read, or any ``FITSError`` raised while parsing the data.
    /// - Note: The file is memory-mapped when safe (`.mappedIfSafe`). If another
    ///   process truncates the file while it is being parsed, accessing the
    ///   vanished pages can raise `SIGBUS` and terminate the process, which no
    ///   Swift error handling can intercept.
    public convenience init( url: URL, options: FITSParsingOptions ) throws
    {
        let data: Data

        do
        {
            data = try Data( contentsOf: url, options: .mappedIfSafe )
        }
        catch
        {
            // Classify the failure only after attempting the read, so there is
            // no time-of-check/time-of-use gap: a missing path or a directory is
            // an invalid URL, anything else is an unreadable file.
            var isDir: ObjCBool = false

            if FileManager.default.fileExists( atPath: url.path, isDirectory: &isDir ) == false || isDir.boolValue
            {
                throw FITSError.invalidFileURL( url: url )
            }

            throw FITSError.cannotReadFile( url: url )
        }

        try self.init( data: data, options: options )
    }

    /// Parses a FITS file from raw bytes.
    ///
    /// Chunks the data into ``blockSize``-byte blocks, groups them into
    /// sections, finalizes each section, then validates that the first section
    /// is a primary header, that mandatory keywords are present and well-formed
    /// in every header and extension, and that each data segment's length
    /// matches the size implied by its header geometry.
    ///
    /// - Parameters:
    ///   - data: The complete file contents.
    ///   - options: The parsing options to apply.
    /// - Throws: ``FITSError/dataError(reason:)`` if the data is empty,
    ///   ``FITSError/invalidFileData(reason:)`` for structural or validation
    ///   failures, or any other ``FITSError`` raised while parsing blocks and
    ///   sections.
    public init( data: Data, options: FITSParsingOptions ) throws
    {
        guard data.isEmpty == false
        else
        {
            throw FITSError.dataError( reason: "Data is empty" )
        }

        var bytes     = data
        let remainder = bytes.count % FITSFile.blockSize

        // A trailing partial block would fail the even-division chunking, which
        // rejects the whole file before any leniency applies. Pad it out to a
        // full block so the original bytes survive and parsing can proceed.
        if remainder != 0, options.contains( .allowTrailingPartialBlock )
        {
            bytes.append( Data( repeating: 0x00, count: FITSFile.blockSize - remainder ) )
        }

        let blocks = try bytes.chunked( by: FITSFile.blockSize ).map
        {
            try FITSBlock( data: $0, options: options )
        }

        self.sections = try FITSFile.sections( from: blocks, options: options )
    }

    /// Builds a file from a list of sections.
    ///
    /// The private designated initializer behind the from-scratch construction
    /// API: it adopts the given sections without parsing or validating. Validation
    /// happens on write, via ``serializedData(options:)``.
    ///
    /// - Parameter sections: The file's sections, in order, starting with the
    ///   primary header.
    private init( sections: [ FITSSection ] )
    {
        self.sections = sections
    }

    /// Builds a primary HDU from scratch, with its mandatory keywords populated to
    /// a standards-compliant minimum.
    ///
    /// Assembles a primary header carrying `SIMPLE`, `BITPIX`, `NAXIS` and one
    /// `NAXISn` per axis, followed by a data segment when `data` is provided. The
    /// file is not validated here; ``serializedData(options:)`` and
    /// ``write(to:options:)`` validate it against the FITS 4.0 standard on write.
    ///
    /// - Parameters:
    ///   - bitpix: The `BITPIX` value (the standard permits 8, 16, 32, 64, -32 and
    ///     -64; an out-of-range value is rejected on write).
    ///   - axes: The `NAXISn` dimensions, in order; its count becomes `NAXIS`. An
    ///     empty array is a `NAXIS = 0` primary with no data.
    ///   - data: The data-segment bytes, or `nil` for none. Defaults to `nil`.
    /// - Throws: Any ``FITSError`` raised while building the mandatory keywords.
    public convenience init( bitpix: Int, axes: [ Int ], data: Data? = nil ) throws
    {
        let properties = try FITSFile.mandatoryPrimaryProperties( bitpix: bitpix, axes: axes )
        let header     = try FITSSection( kind: .header, properties: properties )
        let sections   = data.map { [ header, FITSSection( dataPayload: $0 ) ] } ?? [ header ]

        self.init( sections: sections )
    }

    /// Appends an extension HDU to the file, with its mandatory keywords populated
    /// to a standards-compliant minimum.
    ///
    /// Assembles an extension header carrying `XTENSION`, `BITPIX`, `NAXIS`, one
    /// `NAXISn` per axis, `PCOUNT` and `GCOUNT`, followed by a data segment when
    /// `data` is provided, and appends them to the file. It also declares
    /// `EXTEND = T` in the primary header when not already present (FITS 4.0
    /// §4.4.1.1), placed immediately after the primary's `NAXISn` block.
    ///
    /// The file is not validated here; ``serializedData(options:)`` and
    /// ``write(to:options:)`` validate it on write.
    ///
    /// - Parameters:
    ///   - type: The `XTENSION` type value (e.g. `IMAGE`, `TABLE`, `BINTABLE`).
    ///   - bitpix: The `BITPIX` value.
    ///   - axes: The `NAXISn` dimensions, in order; its count becomes `NAXIS`.
    ///   - pcount: The `PCOUNT` value. Defaults to `0`.
    ///   - gcount: The `GCOUNT` value. Defaults to `1`.
    ///   - data: The data-segment bytes, or `nil` for none. Defaults to `nil`.
    /// - Returns: The appended extension header section, for further editing.
    /// - Throws: ``FITSError/invalidFileData(reason:)`` if the file has no primary
    ///   header, or any ``FITSError`` raised while building the keywords.
    @discardableResult
    public func appendExtension( type: String, bitpix: Int, axes: [ Int ], pcount: Int = 0, gcount: Int = 1, data: Data? = nil ) throws -> FITSSection
    {
        let properties = try FITSFile.mandatoryExtensionProperties( type: type, bitpix: bitpix, axes: axes, pcount: pcount, gcount: gcount )
        let header     = try FITSSection( kind: .xtension, properties: properties )

        try self.declareExtensionsInPrimary()

        self.sections.append( header )

        if let data
        {
            self.sections.append( FITSSection( dataPayload: data ) )
        }

        return header
    }

    /// Builds the mandatory keywords of a primary header — `SIMPLE`, `BITPIX`,
    /// `NAXIS` and one `NAXISn` per axis — in the order FITS 4.0 §4.4.1 requires.
    ///
    /// - Parameters:
    ///   - bitpix: The `BITPIX` value.
    ///   - axes: The `NAXISn` dimensions, in order.
    /// - Returns: The mandatory primary-header properties, in order.
    /// - Throws: Any ``FITSError`` raised while building a property.
    private static func mandatoryPrimaryProperties( bitpix: Int, axes: [ Int ] ) throws -> [ FITSProperty ]
    {
        let head = [
            try FITSProperty( name: "SIMPLE", logical: true,               options: .strict ),
            try FITSProperty( name: "BITPIX", integer: Int64( bitpix ),     options: .strict ),
            try FITSProperty( name: "NAXIS",  integer: Int64( axes.count ), options: .strict ),
        ]

        return head + ( try FITSFile.naxisProperties( axes: axes ) )
    }

    /// Builds the mandatory keywords of an extension header — `XTENSION`, `BITPIX`,
    /// `NAXIS`, one `NAXISn` per axis, `PCOUNT` and `GCOUNT` — in the order
    /// FITS 4.0 §4.4.1 requires.
    ///
    /// - Parameters:
    ///   - type: The `XTENSION` type value.
    ///   - bitpix: The `BITPIX` value.
    ///   - axes: The `NAXISn` dimensions, in order.
    ///   - pcount: The `PCOUNT` value.
    ///   - gcount: The `GCOUNT` value.
    /// - Returns: The mandatory extension-header properties, in order.
    /// - Throws: Any ``FITSError`` raised while building a property.
    private static func mandatoryExtensionProperties( type: String, bitpix: Int, axes: [ Int ], pcount: Int, gcount: Int ) throws -> [ FITSProperty ]
    {
        let head = [
            try FITSProperty( name: "XTENSION", string:  type,               options: .strict ),
            try FITSProperty( name: "BITPIX",   integer: Int64( bitpix ),     options: .strict ),
            try FITSProperty( name: "NAXIS",    integer: Int64( axes.count ), options: .strict ),
        ]
        let tail = [
            try FITSProperty( name: "PCOUNT", integer: Int64( pcount ), options: .strict ),
            try FITSProperty( name: "GCOUNT", integer: Int64( gcount ), options: .strict ),
        ]

        return head + ( try FITSFile.naxisProperties( axes: axes ) ) + tail
    }

    /// Builds the `NAXISn` properties for a set of axis dimensions.
    ///
    /// - Parameter axes: The axis dimensions, in order; axis `n` becomes `NAXISn`.
    /// - Returns: The `NAXISn` properties, in order.
    /// - Throws: Any ``FITSError`` raised while building a property.
    private static func naxisProperties( axes: [ Int ] ) throws -> [ FITSProperty ]
    {
        try axes.enumerated().map
        {
            index, axis in try FITSProperty( name: "NAXIS\( index + 1 )", integer: Int64( axis ), options: .strict )
        }
    }

    /// Declares `EXTEND = T` in the primary header when it is not already present.
    ///
    /// FITS 4.0 §4.4.1.1 requires the primary header to carry `EXTEND = T` when
    /// the file contains extensions. The keyword is inserted immediately after the
    /// primary's `NAXISn` block.
    ///
    /// - Throws: ``FITSError/invalidFileData(reason:)`` if the file has no primary
    ///   header, or any ``FITSError`` raised while inserting the keyword.
    private func declareExtensionsInPrimary() throws
    {
        guard let primary = self.sections.first, primary.kind == .header
        else
        {
            throw FITSError.invalidFileData( reason: "Cannot append an extension without a primary header" )
        }

        guard primary[ "EXTEND" ] == nil
        else
        {
            return
        }

        // Compute the position after the NAXISn block without trapping on a
        // pathological NAXIS: an addition that overflows Int64 can only denote a
        // position past the end, so it clamps to the property count (append).
        let extend                 = try FITSProperty( name: "EXTEND", logical: true, options: .strict )
        let ( position, overflow ) = ( primary.naxis ?? 0 ).addingReportingOverflow( 3 )
        let index                  = overflow ? primary.properties.count : max( 0, min( Int( position ), primary.properties.count ) )

        try primary.insert( extend, at: index )
    }

    /// Removes an extension HDU — its header and any following data segment.
    ///
    /// Only the removed sections change; every other section keeps its bytes (a
    /// clean section still re-emits its retained bytes on write). The primary's
    /// `EXTEND` keyword is left untouched.
    ///
    /// - Parameter index: The 0-based index of the extension among the file's
    ///   extensions (the primary HDU is not counted).
    /// - Throws: ``FITSError/invalidFileData(reason:)`` if `index` is out of range.
    public func removeExtension( at index: Int ) throws
    {
        var units = self.hduUnits()

        // index < units.count - 1 rather than index + 1 < units.count so a
        // pathological index (e.g. Int.max) cannot overflow-trap the addition.
        guard index >= 0, index < units.count - 1
        else
        {
            throw FITSError.invalidFileData( reason: "Extension index \( index ) out of range" )
        }

        units.remove( at: index + 1 )

        self.sections = units.flatMap { $0 }
    }

    /// Moves an extension HDU to a different position among the extensions.
    ///
    /// Moves the whole HDU unit (its header and any following data segment). The
    /// primary HDU is never moved, and the moved sections keep their bytes.
    ///
    /// - Parameters:
    ///   - from: The 0-based index of the extension to move.
    ///   - to: The 0-based index it should occupy after the move.
    /// - Throws: ``FITSError/invalidFileData(reason:)`` if either index is out of
    ///   range.
    public func moveExtension( from: Int, to: Int ) throws
    {
        var units = self.hduUnits()
        let count = units.count - 1

        guard from >= 0, from < count, to >= 0, to < count
        else
        {
            throw FITSError.invalidFileData( reason: "Extension index out of range (from \( from ), to \( to ))" )
        }

        let unit = units.remove( at: from + 1 )

        units.insert( unit, at: to + 1 )

        self.sections = units.flatMap { $0 }
    }

    /// Replaces the primary HDU's data, updating its geometry keywords to match.
    ///
    /// Rewrites the primary header's `BITPIX`, `NAXIS` and `NAXISn` from the
    /// supplied dimensions and sets (or clears) its data segment, so header and
    /// data cannot drift out of sync. The result is still validated on write.
    ///
    /// - Parameters:
    ///   - bitpix: The new `BITPIX` value.
    ///   - axes: The new `NAXISn` dimensions, in order.
    ///   - data: The new data-segment bytes, or `nil` to remove the data segment.
    /// - Throws: ``FITSError/invalidFileData(reason:)`` if the file has no primary
    ///   header, or any ``FITSError`` raised while rewriting the keywords.
    public func setPrimaryData( bitpix: Int, axes: [ Int ], data: Data? ) throws
    {
        guard let primary = self.sections.first, primary.kind == .header
        else
        {
            throw FITSError.invalidFileData( reason: "The file has no primary header" )
        }

        try FITSFile.applyGeometry( to: primary, bitpix: bitpix, axes: axes )
        try self.setDataSegment( afterHeaderAt: 0, data: data )
    }

    /// Replaces an extension HDU's data, updating its geometry keywords to match.
    ///
    /// Rewrites the extension header's `BITPIX`, `NAXIS` and `NAXISn` from the
    /// supplied dimensions (preserving `XTENSION`, `PCOUNT` and `GCOUNT`) and sets
    /// (or clears) its data segment. The result is still validated on write.
    ///
    /// - Parameters:
    ///   - index: The 0-based index of the extension among the file's extensions.
    ///   - bitpix: The new `BITPIX` value.
    ///   - axes: The new `NAXISn` dimensions, in order.
    ///   - data: The new data-segment bytes, or `nil` to remove the data segment.
    /// - Throws: ``FITSError/invalidFileData(reason:)`` if `index` is out of range,
    ///   or any ``FITSError`` raised while rewriting the keywords.
    public func setExtensionData( at index: Int, bitpix: Int, axes: [ Int ], data: Data? ) throws
    {
        let units = self.hduUnits()

        // index < units.count - 1 rather than index + 1 < units.count so a
        // pathological index (e.g. Int.max) cannot overflow-trap the addition.
        guard index >= 0, index < units.count - 1
        else
        {
            throw FITSError.invalidFileData( reason: "Extension index \( index ) out of range" )
        }

        let header = units[ index + 1 ][ 0 ]

        // Locate the header before mutating it, so a failure leaves the file
        // untouched (all-or-nothing).
        guard let headerIndex = self.sections.firstIndex( where: { $0 === header } )
        else
        {
            throw FITSError.invalidFileData( reason: "Extension header not found" )
        }

        try FITSFile.applyGeometry( to: header, bitpix: bitpix, axes: axes )
        try self.setDataSegment( afterHeaderAt: headerIndex, data: data )
    }

    /// Groups the file's sections into HDU units — each a header (or extension)
    /// section plus any immediately-following data segment.
    ///
    /// - Returns: The HDU units in file order; the first is the primary HDU.
    private func hduUnits() -> [ [ FITSSection ] ]
    {
        var units: [ [ FITSSection ] ] = []
        var index                      = 0

        while index < self.sections.count
        {
            let header = self.sections[ index ]
            index     += 1

            if index < self.sections.count, self.sections[ index ].kind == .data
            {
                units.append( [ header, self.sections[ index ] ] )

                index += 1
            }
            else
            {
                units.append( [ header ] )
            }
        }

        return units
    }

    /// Rewrites a header's geometry keywords (`BITPIX`, `NAXIS`, `NAXISn`) from a
    /// set of dimensions, preserving every other keyword.
    ///
    /// `BITPIX` and `NAXIS` are replaced in place; the old `NAXISn` records are
    /// removed and the new set inserted immediately after `NAXIS`, so keywords
    /// that followed the old `NAXISn` block (such as `PCOUNT`/`GCOUNT`) keep their
    /// relative order.
    ///
    /// - Parameters:
    ///   - header: The header or extension section to update.
    ///   - bitpix: The new `BITPIX` value.
    ///   - axes: The new `NAXISn` dimensions, in order.
    /// - Throws: Any ``FITSError`` raised while building or placing a keyword.
    private static func applyGeometry( to header: FITSSection, bitpix: Int, axes: [ Int ] ) throws
    {
        try header.setProperty( FITSProperty( name: "BITPIX", integer: Int64( bitpix ),     options: .strict ) )
        try header.setProperty( FITSProperty( name: "NAXIS",  integer: Int64( axes.count ), options: .strict ) )

        let obsolete = header.properties.map { $0.name }.filter { FITSFile.isNaxisIndex( $0 ) }

        try obsolete.forEach { try header.removeProperties( named: $0 ) }

        let anchor = ( header.properties.firstIndex { $0.name == "NAXIS" } ?? ( header.properties.count - 1 ) ) + 1

        try axes.enumerated().forEach
        {
            index, axis in try header.insert( FITSProperty( name: "NAXIS\( index + 1 )", integer: Int64( axis ), options: .strict ), at: anchor + index )
        }
    }

    /// Reports whether a keyword name is an axis keyword (`NAXIS` followed by a
    /// number), as opposed to the `NAXIS` count keyword itself.
    ///
    /// - Parameter name: The keyword name to test.
    /// - Returns: `true` for `NAXIS1`, `NAXIS2`, …; `false` otherwise.
    private static func isNaxisIndex( _ name: String ) -> Bool
    {
        guard name.hasPrefix( "NAXIS" ), name.count > 5
        else
        {
            return false
        }

        return name.dropFirst( 5 ).allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// Sets, replaces or removes the data segment following a header section.
    ///
    /// - Parameters:
    ///   - headerIndex: The section index of the header the data segment follows.
    ///   - data: The new data-segment bytes, or `nil` to remove any existing one.
    /// - Throws: Any ``FITSError`` raised while replacing an existing payload.
    private func setDataSegment( afterHeaderAt headerIndex: Int, data: Data? ) throws
    {
        let dataIndex = headerIndex + 1
        let hasData   = dataIndex < self.sections.count && self.sections[ dataIndex ].kind == .data

        if let data
        {
            if hasData
            {
                try self.sections[ dataIndex ].setDataPayload( data )
            }
            else
            {
                self.sections.insert( FITSSection( dataPayload: data ), at: dataIndex )
            }
        }
        else if hasData
        {
            self.sections.remove( at: dataIndex )
        }
    }

    /// Groups blocks into sections by following the declared header geometry.
    ///
    /// Reads a header (the first section) or extension up to its `END` block,
    /// finalizes and validates it, then consumes exactly the number of data
    /// blocks its geometry implies before reading the next header/extension.
    ///
    /// - Parameters:
    ///   - blocks: The file's blocks, in order.
    ///   - options: The parsing options to apply.
    /// - Returns: The file's sections, in order, starting with the primary header.
    /// - Throws: ``FITSError/invalidFileData(reason:)`` if a header is missing
    ///   or invalid, the geometry is unsound, or a data segment's length does
    ///   not match the geometry and ``FITSParsingOptions/allowDataLengthMismatch``
    ///   is not set.
    private class func sections( from blocks: [ FITSBlock ], options: FITSParsingOptions ) throws -> [ FITSSection ]
    {
        var sections: [ FITSSection ] = []
        var index                     = 0

        while index < blocks.count
        {
            // Blank blocks remaining after the final HDU are trailing padding,
            // retained for round-tripping rather than parsed as a new HDU.
            if let last = sections.last, blocks[ index ..< blocks.count ].allSatisfy( { $0.data.isBlank } )
            {
                blocks[ index ..< blocks.count ].forEach { last.append( padding: $0 ) }

                break
            }

            let kind: FITSSection.Kind = sections.isEmpty ? .header : .xtension
            let header                 = try FITSSection( kind: kind, block: nil )

            // Accumulate header blocks up to and including the END block.
            while index < blocks.count
            {
                let block = blocks[ index ]
                index    += 1

                try header.append( block: block )

                if block.hasEndMarker
                {
                    break
                }
            }

            try header.finalize( options: options )
            try FITSFile.validateMandatoryKeywords( in: header.properties, isExtension: kind == .xtension )

            sections.append( header )

            let expected   = try FITSFile.expectedDataSize( for: header.properties )
            let blockCount = expected / Int64( FITSFile.blockSize )

            guard blockCount > 0
            else
            {
                continue
            }

            let segment  = try FITSSection( kind: .data, block: nil )
            var consumed  = Int64( 0 )

            while consumed < blockCount, index < blocks.count
            {
                try segment.append( block: blocks[ index ] )
                index    += 1
                consumed += 1
            }

            if consumed != blockCount, options.contains( .allowDataLengthMismatch ) == false
            {
                throw FITSError.invalidFileData( reason: "Data length mismatch: expected \( expected ) bytes but found \( segment.dataSize )" )
            }

            if consumed > 0
            {
                sections.append( segment )
            }
        }

        return sections
    }

    /// Validates the mandatory keywords (name, order and type) common to a
    /// primary header (Table 7) or a conforming extension (Table 10) per
    /// FITS 4.0 §4.4.1: SIMPLE/XTENSION, BITPIX, NAXIS, NAXISn, then PCOUNT and
    /// GCOUNT for extensions. Type-specific keywords (IMAGE/TABLE/BINTABLE, §7)
    /// are not enforced here.
    ///
    /// Ordering is always enforced: each mandatory keyword must occupy its exact
    /// index, even under ``FITSParsingOptions/lenient`` — no parsing option
    /// relaxes this.
    ///
    /// - Parameters:
    ///   - properties: The section's properties, in order.
    ///   - isExtension: `true` to validate as an extension (expecting
    ///     `XTENSION`, `PCOUNT` and `GCOUNT`); `false` for the primary header
    ///     (expecting `SIMPLE`).
    /// - Throws: ``FITSError/invalidFileData(reason:)`` if a mandatory keyword
    ///   is missing, out of order, of the wrong type, or has an invalid value.
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

    /// Expected data-segment size in bytes (padded to a whole number of 2880-byte
    /// blocks) for a header/extension, per the general FITS 4.0 data-size formula
    /// |BITPIX|/8 x GCOUNT x ( PCOUNT + Pi NAXISn ). Absent PCOUNT/GCOUNT default
    /// to 0 and 1, so a standard array reduces to |BITPIX|/8 x Pi NAXISn. For
    /// random groups (GROUPS = T) the first axis is excluded from the product.
    /// NAXIS = 0 means no data follow.
    ///
    /// - Parameter properties: The header or extension properties supplying
    ///   `BITPIX`, `NAXIS`, `NAXISn`, `GROUPS`, `PCOUNT` and `GCOUNT`.
    /// - Returns: The expected data-segment size in bytes, or `0` when no data
    ///   follow (`NAXIS == 0`).
    /// - Throws: ``FITSError/invalidFileData(reason:)`` if the geometry overflows
    ///   a 64-bit size or exceeds ``maxDataSize``.
    private class func expectedDataSize( for properties: [ FITSProperty ] ) throws -> Int64
    {
        // Resolve each keyword once, first occurrence winning, so the per-axis
        // loop below is O(NAXIS) lookups rather than O(NAXIS x |properties|).
        var keywords: [ String: FITSProperty ] = [ : ]

        properties.forEach { keywords[ $0.name ] = keywords[ $0.name ] ?? $0 }

        let bitpix = keywords[ "BITPIX" ]?.value.integer ?? 0
        let naxis  = keywords[ "NAXIS"  ]?.value.integer ?? 0

        guard naxis > 0
        else
        {
            return 0
        }

        // Multiplies two factors, throwing rather than trapping on overflow.
        func multiply( _ a: Int64, by b: Int64 ) throws -> Int64
        {
            let ( result, overflow ) = a.multipliedReportingOverflow( by: b )

            guard overflow == false
            else
            {
                throw FITSError.invalidFileData( reason: "Data geometry overflows 64-bit size" )
            }

            return result
        }

        // Random groups (GROUPS = T) use NAXIS1 = 0 as a group indicator and
        // count the data via GCOUNT/PCOUNT, so the first axis is left out of the
        // element product.
        let groups  = keywords[ "GROUPS" ]?.value.logical ?? false
        var product = Int64( 1 )

        try ( 1 ... naxis ).forEach
        {
            n in

            guard groups == false || n != 1
            else
            {
                return
            }

            product = try multiply( product, by: keywords[ "NAXIS\( n )" ]?.value.integer ?? 0 )
        }

        // |BITPIX|/8 x GCOUNT x (PCOUNT + product), with PCOUNT/GCOUNT defaulting
        // to 0 and 1 so a standard array reduces to |BITPIX|/8 x product.
        let pcount            = keywords[ "PCOUNT" ]?.value.integer ?? 0
        let gcount            = keywords[ "GCOUNT" ]?.value.integer ?? 1
        let ( sum, overflow ) = pcount.addingReportingOverflow( product )

        guard overflow == false
        else
        {
            throw FITSError.invalidFileData( reason: "Data geometry overflows 64-bit size" )
        }

        let elements = try multiply( gcount, by: sum )
        let bytes    = try multiply( abs( bitpix ) / 8, by: elements )

        guard bytes >= 0, bytes <= FITSFile.maxDataSize
        else
        {
            throw FITSError.invalidFileData( reason: "Data geometry exceeds the maximum supported size of \( FITSFile.maxDataSize ) bytes" )
        }

        // Round the byte size up to a whole number of blocks.
        let blockCount = ( bytes + Int64( FITSFile.blockSize ) - 1 ) / Int64( FITSFile.blockSize )

        return blockCount * Int64( FITSFile.blockSize )
    }

    /// Asserts that a property at a given index has the expected name and type.
    ///
    /// Used to enforce the mandatory-keyword name, order and type constraints,
    /// with an optional closure for additional value checks.
    ///
    /// - Parameters:
    ///   - index: The position the property must occupy.
    ///   - properties: The properties to check.
    ///   - name: The keyword name expected at `index`.
    ///   - kind: The value ``FITSValue/Kind`` expected at `index`.
    ///   - validate: An optional closure for extra validation of the value.
    /// - Throws: ``FITSError/invalidFileData(reason:)`` if the property is
    ///   missing, misnamed, of the wrong kind, or rejected by `validate`.
    internal class func validate( index: Int, in properties: [ FITSProperty ], name: String, kind: FITSValue.Kind, validate: ( ( FITSValue ) throws -> Void )? = nil ) throws
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

    /// The complete file contents, serialized and validated with the ``strict``
    /// options.
    ///
    /// A convenience for ``serializedData(options:)`` with
    /// ``FITSSerializationOptions/strict``. An unmodified parsed file yields its
    /// original bytes byte-for-byte; a file whose sections were modified
    /// re-renders those sections from their model.
    ///
    /// - Throws: ``FITSError/invalidFileData(reason:)`` if strict validation
    ///   fails, or any ``FITSError`` raised while rendering a modified section.
    public var data: Data
    {
        get throws
        {
            try self.serializedData( options: .strict )
        }
    }

    /// The complete file contents, validated then serialized.
    ///
    /// Validates the file against the FITS 4.0 standard (mandatory keywords,
    /// `BITPIX`/`NAXIS` geometry, data-segment size, and primary-HDU-first
    /// ordering), then concatenates every section's serialized bytes. An
    /// unmodified parsed file reproduces its original bytes byte-for-byte;
    /// modified sections are re-rendered from their model.
    ///
    /// - Parameter options: The serialization options to apply. ``strict``
    ///   enforces the full standard; ``lenient`` relaxes the data-size check and
    ///   coerces invalid keywords.
    /// - Returns: The complete file bytes, a whole number of 2880-byte blocks.
    /// - Throws: ``FITSError/invalidFileData(reason:)`` if validation fails, or
    ///   any ``FITSError`` raised while rendering a section.
    public func serializedData( options: FITSSerializationOptions ) throws -> Data
    {
        try self.validateForSerialization( options: options )

        let size = self.sections.reduce( 0 ) { $0 + $1.serializedByteCount }
        var data = Data( capacity: size )

        try self.sections.forEach
        {
            try $0.appendSerializedData( to: &data, options: options )
        }

        return data
    }

    /// Serializes the file and writes it to a URL.
    ///
    /// Serializes via ``serializedData(options:)`` — which validates first — then
    /// writes the bytes atomically, replacing any existing file.
    ///
    /// - Parameters:
    ///   - url: The location to write to.
    ///   - options: The serialization options to apply.
    /// - Throws: ``FITSError/cannotWriteFile(url:)`` if the bytes cannot be
    ///   written, or any ``FITSError`` raised while validating or serializing.
    public func write( to url: URL, options: FITSSerializationOptions ) throws
    {
        let data = try self.serializedData( options: options )

        do
        {
            try data.write( to: url, options: .atomic )
        }
        catch
        {
            throw FITSError.cannotWriteFile( url: url )
        }
    }

    /// Validates the file's structure before serialization.
    ///
    /// Walks the sections as header/extension units each optionally followed by a
    /// data segment: the first section must be the primary header; every header
    /// and extension must carry well-formed mandatory keywords (Sect. 4.4.1); and
    /// each data segment's size must match the geometry, unless
    /// ``FITSSerializationOptions/allowDataSizeMismatch`` is set.
    ///
    /// - Parameter options: The serialization options to apply.
    /// - Throws: ``FITSError/invalidFileData(reason:)`` if the file is empty, a
    ///   section is out of place, a mandatory keyword is invalid, or a data
    ///   segment's size does not match its geometry.
    private func validateForSerialization( options: FITSSerializationOptions ) throws
    {
        guard self.sections.first?.kind == .header
        else
        {
            throw FITSError.invalidFileData( reason: "The first section must be the primary header" )
        }

        var index = 0

        while index < self.sections.count
        {
            let section = self.sections[ index ]

            guard section.kind == .header || section.kind == .xtension
            else
            {
                throw FITSError.invalidFileData( reason: "Unexpected data segment at index \( index ): a data segment can only follow a header or extension that declares data (a NAXIS = 0 HDU has none)" )
            }

            try FITSFile.validateMandatoryKeywords( in: section.properties, isExtension: section.kind == .xtension )

            let expected = try FITSFile.expectedDataSize( for: section.properties )
            index       += 1

            guard expected > 0
            else
            {
                continue
            }

            guard index < self.sections.count, self.sections[ index ].kind == .data
            else
            {
                guard options.contains( .allowDataSizeMismatch )
                else
                {
                    throw FITSError.invalidFileData( reason: "Missing data segment: expected \( expected ) bytes" )
                }

                continue
            }

            let actual = Int64( self.sections[ index ].serializedByteCount )
            index     += 1

            guard actual == expected || options.contains( .allowDataSizeMismatch )
            else
            {
                throw FITSError.invalidFileData( reason: "Data size mismatch: expected \( expected ) bytes but found \( actual )" )
            }
        }
    }

    /// The primary header section, or `nil` if the file has no sections.
    public var header: FITSSection?
    {
        return self.sections.first
    }

    /// The extension sections, in file order.
    public var extensions: [ FITSSection ]
    {
        return self.sections.filter { $0.kind == .xtension }
    }

    /// A multi-line, human-readable summary of the file and its sections.
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
