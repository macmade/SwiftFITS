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

/// Options controlling how strictly FITS data is validated and rendered when
/// serialized back to bytes.
///
/// This is the write-side counterpart to ``FITSParsingOptions``. It offers the
/// same two presets — ``strict`` and ``lenient`` — so a consumer can choose
/// between spec-faithful output that rejects anything the FITS standard forbids
/// and real-world-friendly output that tolerates the same noncompliant
/// constructs the parser accepts.
///
/// The concrete option flags are introduced as the writer is built out across
/// the serialization milestones (value and card rendering, section assembly,
/// on-write validation); until then both presets are the empty set, meaning
/// "no special behavior".
public struct FITSSerializationOptions: OptionSet, Sendable
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

    /// Spec-faithful serialization: emits standards-compliant bytes and rejects
    /// any content the FITS standard forbids.
    ///
    /// Concrete flags are added to this preset as the writer's validation and
    /// rendering rules are implemented.
    public static let strict: FITSSerializationOptions = []

    /// Real-world-friendly serialization: like ``strict`` but tolerates the
    /// noncompliant constructs found in many existing FITS files.
    ///
    /// Concrete flags are added to this preset as the writer's leniency rules
    /// are implemented.
    public static let lenient: FITSSerializationOptions = []
}
