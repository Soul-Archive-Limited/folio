import SwiftUI

/// Tags each word of the greeting so `WordRevealRenderer` can stagger them.
struct WordIndexAttribute: TextAttribute {
    let index: Int
}
