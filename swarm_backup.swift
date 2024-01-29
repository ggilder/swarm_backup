import Foundation

// MARK: - Model

struct Credentials: Decodable {
    let wsid: String
    let oauth_token: String
    let user_id: String
}

// MARK: - Main

func main() {
    guard let credentialsData = try? Data(contentsOf: URL(fileURLWithPath: "credentials.json")),
          let credentials = try? JSONDecoder().decode(Credentials.self, from: credentialsData) else {
        print("Error reading or decoding credentials.json.")
        return
    }

    let outputDirectory = getOutputDirectory()
    let baseURL = "https://api.foursquare.com/v2/users/\(credentials.user_id)/checkins?locale=en&explicit-lang=false&v=20231221&offset=%d&limit=50&m=swarm&clusters=false&wsid=\(credentials.wsid)&oauth_token=\(credentials.oauth_token)"

    var fullURL = baseURL

    // Get the latest file in the output directory
    if let latestFile = getLatestFile(in: outputDirectory),
       let createdAtTimestamp = getTimestamp(from: latestFile) {
        let afterTimestampParameter = "&afterTimestamp=\(Int(createdAtTimestamp))"
        fullURL += afterTimestampParameter
        print("Querying URL with afterTimestamp parameter:", createdAtTimestamp)
    }

    // Continue with the rest of the script
    var offset = 0

    while true {
        print("Fetching checkins at offset \(offset)")
        guard let items = fetchCheckinData(urlString: String(format: fullURL, offset)),
              !items.isEmpty else {
            break
        }

        for item in items {
            do {
                try saveCheckinItem(item, to: outputDirectory)
            } catch {
                print("Error encountered while saving checkin item: \(error)")
                exit(1)
            }
        }

        offset += items.count
    }
}

// MARK: - Networking

func fetchCheckinData(urlString: String) -> [[String: Any]]? {
    guard let url = URL(string: urlString),
          let data = try? Data(contentsOf: url),
          let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
          let response = json["response"] as? [String: Any],
          let checkins = response["checkins"] as? [String: Any],
          let items = checkins["items"] as? [[String: Any]] else {
        print("Error fetching or decoding checkin data from \(urlString).")
        return nil
    }

    return items
}

// MARK: - File Handling

func getOutputDirectory() -> String {
    let arguments = CommandLine.arguments
    guard let outputIndex = arguments.firstIndex(of: "--output"), outputIndex + 1 < arguments.count else {
        print("Please provide an output directory using the --output flag.")
        exit(1)
    }

    return arguments[outputIndex + 1]
}

func saveCheckinItem(_ item: [String: Any], to outputDirectory: String) throws {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HHmm"

    let baseURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)

    let createdAt = item["createdAt"] as! TimeInterval
    let timeZoneOffset = item["timeZoneOffset"] as! Int
    dateFormatter.timeZone = TimeZone(secondsFromGMT: timeZoneOffset * 60)

    let localDate = dateFormatter.string(from: Date(timeIntervalSince1970: createdAt))

    var venueName = ""
    if let venue = item["venue"] as? [String: Any], let name = venue["name"] as? String {
        // Replace colon and slash with underscores in the venue name
        venueName = name.replacingOccurrences(of: #"[/:]"#, with: "_", options: .regularExpression)
    }

    let fileName = "\(localDate) \(venueName).json"

    do {
        let itemData = try JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
        // Just remove accents because constructing a URL will not respect Unicode Normalization Forms :/
        let itemURL = URL(fileURLWithPath: fileName.folding(options: .diacriticInsensitive, locale: .current), relativeTo: baseURL)
        try itemData.write(to: itemURL, options: .atomic)
    } catch {
        throw error
    }
}

// MARK: - Utility Functions

func getLatestFile(in directory: String) -> String? {
    guard let fileURLs = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
        return nil
    }

    return fileURLs
        .filter { $0.hasSuffix(".json") }
        .sorted { $0.lexicographicallyPrecedes($1) }
        .last
}

func getTimestamp(from fileName: String) -> TimeInterval? {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HHmm"

    // Extract timestamp from file name
    if let range = fileName.range(of: "\\d{4}-\\d{2}-\\d{2} \\d{4}", options: .regularExpression) {
        let timestampString = fileName[range].trimmingCharacters(in: .whitespacesAndNewlines)
        return dateFormatter.date(from: timestampString)?.timeIntervalSince1970
    }

    return nil
}

// Run the script
main()
