import Foundation

// MARK: - Model

struct Credentials: Decodable {
    let wsid: String
    let oauthToken: String
    let userId: String
}

struct CheckinResponse: Decodable {
    let response: CheckinData
}

struct CheckinData: Decodable {
    let checkins: Checkins
}

struct Checkins: Decodable {
    let count: Int
    let items: [CheckinItem]
}

struct CheckinItem: Decodable {
    let createdAt: TimeInterval
    let timeZoneOffset: Int
    let venue: Venue
}

struct Venue: Decodable {
    let name: String
}

// MARK: - Main

func main() {
    guard let credentialsData = try? Data(contentsOf: URL(fileURLWithPath: "credentials.json")),
          let credentials = try? JSONDecoder().decode(Credentials.self, from: credentialsData) else {
        print("Error reading or decoding credentials.json.")
        return
    }

    let outputDirectory = getOutputDirectory()
    let baseURL = "https://api.foursquare.com/v2/users/\(credentials.userId)/checkins?locale=en&explicit-lang=false&v=20231221&offset=%d&limit=50&m=swarm&clusters=false&wsid=\(credentials.wsid)&oauth_token=\(credentials.oauthToken)"

    var offset = 0

    while true {
        guard let checkinData = fetchCheckinData(urlString: String(format: baseURL, offset)),
              let items = checkinData.response.checkins.items,
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

func fetchCheckinData(urlString: String) -> CheckinResponse? {
    guard let url = URL(string: urlString),
          let data = try? Data(contentsOf: url),
          let checkinData = try? JSONDecoder().decode(CheckinResponse.self, from: data) else {
        print("Error fetching or decoding checkin data from \(urlString).")
        return nil
    }

    return checkinData
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
    dateFormatter.timeZone = TimeZone(secondsFromGMT: item["timeZoneOffset"] as! Int * 60)

    let localDate = dateFormatter.string(from: Date(timeIntervalSince1970: item["createdAt"] as! TimeInterval))
    let fileName = "\(localDate) \(item["venue"]!["name"] as! String).json"
    let filePath = (outputDirectory as NSString).appendingPathComponent(fileName)

    do {
        let itemData = try JSONSerialization.data(withJSONObject: item, options: .prettyPrinted)
        try itemData.write(to: URL(fileURLWithPath: filePath), options: .atomicWrite)
    } catch {
        print("Error writing checkin item to file: \(error)")
    }
}

// Run the script
main()
