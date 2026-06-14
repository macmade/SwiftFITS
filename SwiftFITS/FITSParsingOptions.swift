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

public struct FITSParsingOptions: OptionSet, Sendable
{
    public let rawValue: Int

    public init( rawValue: Int )
    {
        self.rawValue = rawValue
    }

    // Spec conveniences (multi-record value handling) - present in both modes.
    public static let mergeHistoryProperties      = FITSParsingOptions( rawValue: 1 << 0 )
    public static let mergeCommentProperties      = FITSParsingOptions( rawValue: 1 << 1 )
    public static let mergeStringProperties       = FITSParsingOptions( rawValue: 1 << 2 )

    // Leniency flags (accept technically-noncompliant input) - lenient mode only.
    public static let allowUnknownProperties      = FITSParsingOptions( rawValue: 1 << 3 )
    public static let allowTrailingQuoteJunk      = FITSParsingOptions( rawValue: 1 << 4 )
    public static let allowNonPrintableHeaderText = FITSParsingOptions( rawValue: 1 << 5 )

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
    ]
}
