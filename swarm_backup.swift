/*
TODO:
- Have script only request checkins newer than most recent one in output folder?
- Could potentially winnow down output keys a bit
- Or save some jq scripts ("views?") to display the essentials from checkin files
*/

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

    var offset = 0

    // Temp for testing
    while true && offset < 50 {
        guard let items = fetchCheckinData(urlString: String(format: baseURL, offset)),
              !items.isEmpty else {
            break
        }

        for item in items {
            saveCheckinItem(item, to: outputDirectory)
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

func saveCheckinItem(_ item: [String: Any], to outputDirectory: String) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HHmm"

    let createdAt = item["createdAt"] as! TimeInterval
    let timeZoneOffset = item["timeZoneOffset"] as! Int
    dateFormatter.timeZone = TimeZone(secondsFromGMT: timeZoneOffset * 60)

    let localDate = dateFormatter.string(from: Date(timeIntervalSince1970: createdAt))

    var venueName = ""
    if let venue = item["venue"] as? [String: Any], let name = venue["name"] as? String {
        venueName = name
    }

    let fileName = "\(localDate) \(venueName).json"
    let filePath = (outputDirectory as NSString).appendingPathComponent(fileName)

    do {
        let itemData = try JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
        try itemData.write(to: URL(fileURLWithPath: filePath), options: .atomic)
    } catch {
        print("Error writing checkin item to file: \(error)")
    }
}

// Run the script
main()
