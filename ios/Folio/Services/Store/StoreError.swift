import Foundation

/// Validation failures the UI turns into friendly, inline messages.
enum StoreError: Error, Equatable {
    case categoryNameEmpty
    case categoryNameTooLong
    case duplicateCategoryName
    case tooManyCategories
    case titleTooLong
    case taskTitleEmpty
    case notesTooLong
    case tooManyPhotos
}
