import Foundation

public enum ProfileStoreCoding {
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(makeFormatter().string(from: date))
        }
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatter = makeFormatter()
            guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Expected a UTC ISO-8601 timestamp without fractional seconds."
                )
            }
            return date
        }
        return decoder
    }

    private static func makeFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}
