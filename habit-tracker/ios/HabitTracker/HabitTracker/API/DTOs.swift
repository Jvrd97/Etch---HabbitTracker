// [review:need-review] PHASE-01/05-ios-today-quick-entry
// summary: Codable DTOs mirroring backend schemas — typed FieldTypeDTO enum, checklist upsert payload
import Foundation

/// Category with its field definitions, as returned by `GET /api/v1/categories`.
struct CategoryDTO: Codable, Identifiable, Equatable {
    /// Backend `display_mode` value that switches Today to the checklist upsert flow.
    static let checklistDisplayMode = "checklist"

    let id: Int
    let name: String
    let icon: String?
    let color: String?
    let displayMode: String
    let isActive: Bool
    let fields: [FieldDTO]

    /// Checklist categories save via idempotent `PUT /entries/checklist`, not generic POST.
    var isChecklist: Bool {
        displayMode == Self.checklistDisplayMode
    }
}

/// Field type mirroring the backend `FieldType` enum; `unknown` keeps decoding
/// forward-compatible when the server introduces a type this client predates.
enum FieldTypeDTO: Equatable {
    case text
    case number
    case boolean
    case date
    case datetime
    case time
    case select
    case duration
    case unknown(String)
}

extension FieldTypeDTO: RawRepresentable, Codable {
    private static let knownCases: [String: FieldTypeDTO] = [
        "text": .text,
        "number": .number,
        "boolean": .boolean,
        "date": .date,
        "datetime": .datetime,
        "time": .time,
        "select": .select,
        "duration": .duration,
    ]

    init(rawValue: String) {
        self = Self.knownCases[rawValue] ?? .unknown(rawValue)
    }

    // Explicit switch (no reverse map lookup): a lookup would compare via `==`,
    // which for RawRepresentable types is itself defined through `rawValue` —
    // that pair recurses until the stack blows.
    var rawValue: String {
        switch self {
        case .text: return "text"
        case .number: return "number"
        case .boolean: return "boolean"
        case .date: return "date"
        case .datetime: return "datetime"
        case .time: return "time"
        case .select: return "select"
        case .duration: return "duration"
        case .unknown(let raw): return raw
        }
    }

    init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Field definition inside a category (drives the dynamic entry form).
struct FieldDTO: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let fieldType: FieldTypeDTO
    let isRequired: Bool
    let defaultValue: String?
    let options: String?
    let order: Int
}

/// Single field value inside an entry; also used as the create payload item.
struct EntryValueDTO: Codable, Equatable {
    let fieldId: Int
    let value: String?
}

/// Entry as returned by `GET /api/v1/entries`.
struct EntryDTO: Codable, Identifiable, Equatable {
    let id: Int
    let categoryId: Int
    let entryDate: String
    let values: [EntryValueDTO]
}

/// Payload for `POST /api/v1/entries`.
struct EntryCreateDTO: Codable, Equatable {
    let categoryId: Int
    let entryDate: String
    let notes: String?
    let values: [EntryValueDTO]
}

/// Payload for idempotent `PUT /api/v1/entries/checklist`.
/// `values` is keyed by the field id as a String: the backend expects a JSON
/// object `{ "<field_id>": bool }`, and Swift would encode `[Int: Bool]` as an array.
struct ChecklistUpsertDTO: Codable, Equatable {
    let categoryId: Int
    let entryDate: String
    let values: [String: Bool]
}

enum APIJSONCoding {
    /// Decoder matching the backend's snake_case JSON.
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    /// Encoder producing the backend's snake_case JSON.
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}
