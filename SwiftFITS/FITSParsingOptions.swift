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
    public static let allowNulPadding = FITSParsingOptions( rawValue: 1 << 9 )

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
    ]
}
