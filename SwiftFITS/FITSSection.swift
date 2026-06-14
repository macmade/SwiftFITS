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

/// A contiguous run of FITS blocks forming one logical unit.
///
/// A section is either the primary header, an extension header, or a data
/// segment. Header and extension sections parse their blocks into
/// ``properties``; data sections retain their raw blocks. Blocks are appended
/// as the file is scanned, then ``finalize(options:)`` parses and validates
/// the accumulated content.
///
/// A section holds mutable parsing state and composes ``FITSBlock``, so it is
/// not thread-safe and not `Sendable`.
public class FITSSection: CustomStringConvertible
{
    /// The role a ``FITSSection`` plays in the file.
    public enum Kind: CustomStringConvertible
    {
        /// The primary header (the first section of the file).
        case header

        /// An extension header introduced by an `XTENSION` block.
        case xtension

        /// A data segment following a header or extension.
        case data

        /// A human-readable name for the kind.
        public var description: String
        {
            switch self
            {
                case .header:   return "Header"
                case .xtension: return "Extension"
                case .data:     return "Data"
            }
        }
    }

    /// The role this section plays in the file.
    public let kind: Kind

    /// The raw blocks making up the section, in file order.
    private var blocks: [ FITSBlock ] = []

    /// Whether ``finalize(options:)`` has completed, after which structural
    /// blocks can no longer be appended (so ``properties`` and ``blocks`` cannot
    /// disagree).
    private var isFinalized = false

    /// The parsed header records. Empty for data sections, and until
    /// ``finalize(options:)`` has run.
    ///
    /// The `END` marker is excluded from this list, but it round-trips through
    /// ``data`` since the raw block bytes are retained.
    public private( set ) var properties: [ FITSProperty ] = []

    /// Creates a section of the given kind, optionally seeded with a first block.
    ///
    /// - Parameters:
    ///   - kind: The role this section plays.
    ///   - block: An initial block to append, or `nil` to start empty.
    /// - Throws: ``FITSError/invalidBlockData(reason:)`` if the initial block
    ///   is not valid for the section kind.
    public init( kind: Kind, block: FITSBlock? ) throws
    {
        self.kind = kind

        if let block = block
        {
            try self.append( block: block )
        }
    }

    /// The total size, in bytes, of all blocks in the section.
    public var dataSize: Int
    {
        self.blocks.reduce( 0 ) { $0 + $1.data.count }
    }

    /// The concatenated raw bytes of every block in the section.
    public var data: Data
    {
        let size = self.dataSize
        var data = Data( capacity: size )

        self.blocks.forEach
        {
            data.append( $0.data )
        }

        return data
    }

    /// A Boolean value indicating whether another block may be appended.
    ///
    /// Data sections always accept more blocks. Header and extension sections
    /// stop accepting blocks once their last block carries the `END` marker.
    public var canAppendData: Bool
    {
        self.kind == .data || ( self.blocks.last?.hasEndMarker ?? false ) == false
    }

    /// Appends a block to the section.
    ///
    /// For header and extension sections this enforces structural rules: the
    /// block must be ASCII, must not follow an `END` marker, and must not
    /// introduce a new extension mid-section.
    ///
    /// - Parameter block: The block to append.
    /// - Throws: ``FITSError/invalidSectionData(reason:)`` if the section is
    ///   already finalized, or ``FITSError/invalidBlockData(reason:)`` if
    ///   appending the block would violate the structural rules.
    internal func append( block: FITSBlock ) throws
    {
        guard self.isFinalized == false
        else
        {
            throw FITSError.invalidSectionData( reason: "Cannot append to a finalized section" )
        }

        if self.kind == .header || self.kind == .xtension
        {
            if block.containsOnlyASCII == false
            {
                throw FITSError.invalidBlockData( reason: "Headers or extensions must contain only ASCII data" )
            }

            if let last = self.blocks.last
            {
                if last.hasEndMarker
                {
                    throw FITSError.invalidBlockData( reason: "Cannot append data to a section with an end marker" )
                }

                if block.hasExtensionMarker
                {
                    throw FITSError.invalidBlockData( reason: "Cannot append an extension to a header or extension with existing data" )
                }
            }
        }

        self.blocks.append( block )
    }

    /// Appends a trailing padding block as-is.
    ///
    /// Bypasses the header structural rules so blank end-of-file padding
    /// round-trips through ``data`` without being parsed as content.
    ///
    /// - Parameter block: The padding block to retain.
    internal func append( padding block: FITSBlock )
    {
        self.blocks.append( block )
    }

    /// Parses and validates a header or extension section's accumulated blocks.
    ///
    /// Verifies printability, reads and merges the 80-byte records into
    /// ``properties``, enforces a single `END` marker, optionally rejects
    /// unknown-typed records, and trims trailing blank records up to the `END`
    /// marker. Has no effect on data sections.
    ///
    /// - Parameter options: The parsing options to apply.
    /// - Throws: ``FITSError/invalidSectionData(reason:)`` if the section is
    ///   already finalized, non-printable, has no or multiple `END` markers, or
    ///   contains an unknown property when not permitted.
    internal func finalize( options: FITSParsingOptions ) throws
    {
        guard self.isFinalized == false
        else
        {
            throw FITSError.invalidSectionData( reason: "Section already finalized" )
        }

        if self.kind == .header || self.kind == .xtension
        {
            if options.contains( .allowNonPrintableHeaderText ) == false, self.data.containsOnlyFITSPrintable == false
            {
                throw FITSError.invalidSectionData( reason: "Header contains non-printable characters" )
            }

            let properties = try FITSSection.readAndMergeProperties( data: self.data, options: options )

            if properties.count( where: { $0.name == "END" } ) > 1
            {
                throw FITSError.invalidSectionData( reason: "Multiple end markers found" )
            }

            guard let index = properties.firstIndex( where: { $0.name == "END" } )
            else
            {
                throw FITSError.invalidSectionData( reason: "No end marker found" )
            }

            if options.contains( .allowUnknownProperties ) == false, let unknown = properties.first( where: { $0.value.kind == .unknown } )
            {
                throw FITSError.invalidSectionData( reason: "Unknown property found: \( unknown.name )" )
            }

            let lastNonEmpty = properties[ 0 ..< index ].lastIndex
            {
                $0.name.isEmpty == false || $0.value.kind != .undefined || $0.comment != nil
            }

            if let lastNonEmpty
            {
                self.properties = Array( properties[ 0 ... lastNonEmpty ] )
            }
            else
            {
                self.properties = Array( properties[ 0 ..< index ] )
            }
        }

        self.isFinalized = true
    }

    /// Splits header data into 80-byte records and merges continuation records.
    ///
    /// Each 80-byte chunk becomes a ``FITSProperty``; `CONTINUE`, `HISTORY` and
    /// `COMMENT` records are folded into their predecessor when the
    /// corresponding merge option is enabled.
    ///
    /// - Parameters:
    ///   - data: The full ASCII bytes of the header or extension.
    ///   - options: The parsing options to apply.
    /// - Returns: The parsed (and merged) properties in file order.
    /// - Throws: ``FITSError`` if a record cannot be parsed, or
    ///   ``FITSError/invalidSectionData(reason:)`` if a continuation record has
    ///   no predecessor to merge into.
    private class func readAndMergeProperties( data: Data, options: FITSParsingOptions ) throws -> [ FITSProperty ]
    {
        try data.chunked( by: 80 ).map
        {
            try FITSProperty( data: $0, options: options )
        }
        .reduce( into: [ FITSProperty ]() )
        {
            if $1.name == "CONTINUE", options.contains( .mergeStringProperties )
            {
                guard let last = $0.last
                else
                {
                    throw FITSError.invalidSectionData( reason: "No previous property to continue" )
                }

                try last.merge( with: $1 )
            }
            else if let last = $0.last, last.name == "HISTORY", $1.name == "HISTORY", options.contains( .mergeHistoryProperties )
            {
                try last.merge( with: $1 )
            }
            else if let last = $0.last, last.name == "COMMENT", $1.name == "COMMENT", options.contains( .mergeCommentProperties )
            {
                try last.merge( with: $1 )
            }
            else
            {
                $0.append( $1 )
            }
        }
    }

    /// A multi-line, human-readable summary of the section.
    public var description: String
    {
        self.description( indent: 0 )
    }

    /// A multi-line, human-readable summary of the section, indented for nesting.
    ///
    /// - Parameter indent: The indentation depth, in units of four spaces.
    /// - Returns: The formatted description.
    public func description( indent: Int ) -> String
    {
        let indent     = String( repeating: " ", count: indent * 4 )
        let dataSize   = self.dataSize
        let properties = if self.properties.isEmpty == false
        {
            """

            \( indent )    Properties:
            \( indent )    [
            \( indent )        \( self.properties.map { $0.description }.joined( separator: "\n\( indent )        " ) )
            \( indent )    ]
            """
        }
        else
        {
            ""
        }

        return """
            \( indent )FITSSection 
            \( indent ){
            \( indent )    Kind:       \( self.kind )
            \( indent )    Chunks:     \( self.blocks.count )
            \( indent )    Data Size:  \( dataSize )\( properties )
            \( indent )}
            """
    }
}
