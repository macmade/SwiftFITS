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

/// Options controlling how strictly FITS data is parsed and validated.
///
/// The set divides into two groups: *spec conveniences* that reassemble
/// values spread across several records (present in both ``strict`` and
/// ``lenient``), and *leniency flags* that tolerate technically-noncompliant
/// input (present only in ``lenient``).
public struct FITSParsingOptions: OptionSet, Sendable
{
    /// The raw bitmask backing the option set.
    public let rawValue: Int

    /// Creates an option set from its raw bitmask value.
    ///
    /// - Parameter rawValue: The bitmask of enabled options.
    public init( rawValue: Int )
    {
        self.rawValue = rawValue
    }

    // Spec conveniences (multi-record value handling) - present in both modes.

    /// Merge consecutive `HISTORY` records into a single property.
    public static let mergeHistoryProperties = FITSParsingOptions( rawValue: 1 << 0 )

    /// Merge consecutive `COMMENT` records into a single property.
    public static let mergeCommentProperties = FITSParsingOptions( rawValue: 1 << 1 )

    /// Reassemble long string values split across `CONTINUE` records.
    public static let mergeStringProperties = FITSParsingOptions( rawValue: 1 << 2 )

    // Leniency flags (accept technically-noncompliant input) - lenient mode only.

    /// Accept records whose value does not match any known FITS type instead
    /// of rejecting the section.
    public static let allowUnknownProperties = FITSParsingOptions( rawValue: 1 << 3 )

    /// Tolerate non-blank characters between a string value's closing quote and
    /// its comment delimiter, dropping them instead of failing.
    public static let allowTrailingQuoteJunk = FITSParsingOptions( rawValue: 1 << 4 )

    /// Accept header text containing characters outside the printable FITS
    /// range (`0x20...0x7E`).
    public static let allowNonPrintableHeaderText = FITSParsingOptions( rawValue: 1 << 5 )

    /// Accept a data segment whose length does not match the size implied by
    /// the header geometry.
    public static let allowDataLengthMismatch = FITSParsingOptions( rawValue: 1 << 6 )

    /// Accept a value indicator (`=`) not followed by the mandatory space,
    /// reclassifying the remainder of the record as a comment instead of
    /// failing.
    public static let allowMissingValueIndicatorSpace = FITSParsingOptions( rawValue: 1 << 7 )

    /// Accept lowercase `e`/`d` exponent markers in floating-point values,
    /// classifying them as floats instead of unknown values. FITS 4.0 requires
    /// the uppercase `E`/`D` markers, which strict parsing still enforces.
    public static let allowLowercaseExponents = FITSParsingOptions( rawValue: 1 << 8 )

    /// Treat the NUL byte (`0x00`) as record padding, so NUL-padded or
    /// NUL-terminated keywords and `END` markers are recognized. FITS 4.0 pads
    /// with the ASCII space (`0x20`) only, which strict parsing still enforces.
    ///
    /// This flag is scoped to keyword-name and `END`-marker recognition only.
    /// To extend NUL-aware padding to value and comment fields, also set
    /// ``allowNulPaddingInValues``.
    public static let allowNulPadding = FITSParsingOptions( rawValue: 1 << 9 )

    /// Accept a file whose total length is not a multiple of the 2880-byte block
    /// size by zero-padding the trailing partial block to full size. FITS 4.0
    /// requires whole blocks, which strict parsing still enforces.
    public static let allowTrailingPartialBlock = FITSParsingOptions( rawValue: 1 << 10 )

    /// Tolerate non-blank records following the `END` marker, dropping them
    /// from a section's properties instead of failing. FITS 4.0 allows only
    /// blank padding after `END`, which strict parsing still enforces. The
    /// dropped records' bytes are retained, so the file still round-trips.
    public static let allowContentAfterEnd = FITSParsingOptions( rawValue: 1 << 11 )

    /// Treat the NUL byte (`0x00`) as record padding in value and comment
    /// fields, so a NUL-padded or NUL-terminated value such as `T\0\0\0` is
    /// trimmed and classified normally rather than left as an unknown value.
    ///
    /// Complements ``allowNulPadding`` (which covers only keyword names and the
    /// `END` marker); the two are independent and may be set separately. FITS
    /// 4.0 pads with the ASCII space (`0x20`) only, which strict parsing still
    /// enforces.
    public static let allowNulPaddingInValues = FITSParsingOptions( rawValue: 1 << 12 )

    /// Tolerate a `CONTINUE` record that cannot be merged into a predecessor —
    /// because there is no preceding property, or the predecessor is not a
    /// string ending in the `&` continuation flag — by keeping it as a
    /// standalone property instead of rejecting the section. Requires
    /// ``mergeStringProperties`` to be set (otherwise no merge is attempted and
    /// `CONTINUE` records are already standalone).
    public static let allowOrphanedContinue = FITSParsingOptions( rawValue: 1 << 13 )

    /// Spec-faithful parsing: reconstructs multi-record values but rejects any
    /// input the FITS standard forbids.
    public static let strict: FITSParsingOptions = [
        .mergeHistoryProperties,
        .mergeCommentProperties,
        .mergeStringProperties,
    ]

    /// Real-world-friendly parsing: like ``strict`` but tolerates the
    /// noncompliant constructs found in many existing FITS files.
    public static let lenient: FITSParsingOptions = [
        .strict,
        .allowUnknownProperties,
        .allowTrailingQuoteJunk,
        .allowNonPrintableHeaderText,
        .allowDataLengthMismatch,
        .allowMissingValueIndicatorSpace,
        .allowLowercaseExponents,
        .allowNulPadding,
        .allowTrailingPartialBlock,
        .allowContentAfterEnd,
        .allowNulPaddingInValues,
        .allowOrphanedContinue,
    ]
}
