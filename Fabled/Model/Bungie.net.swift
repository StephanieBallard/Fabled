import Foundation

/// Bungo.
public enum Bungie {

    /// Our application key generated by Bungie.
    /// - Warning: An exception is raised if a key is not set prior to making a request.
    public static var key: String?

    /// Our application id generated by Bungie.
    /// - Warning: An exception is raised if an id is not set prior to making a request.
    public static var appId: String?

    /// The current version of the Fabled app target. Used to create the user agent string.
    /// - Warning: An exception is raised if a version is not set prior to making a request.
    public static var appVersion: String?

    /// Our decoder.
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    enum API {
        case getPlayer(withId: String, onPlatform: Platform)
        case getFindPlayer(withQuery: String, onPlatform: Platform)
        case getCompetitiveHistory(forCharacterWithId: String, associatedWithPlayerId: String, onPlatform: Platform)

        var request: URLRequest {
            guard let key = key else { fatalError("Fabled: A request was attempted before `Bungie.key` was set.") }
            guard let appId = appId else { fatalError("Fabled: A request was attempted before `Bungie.appId` was set.") }
            guard let appVersion = appVersion else { fatalError("Fabled: A request was attempted before `Bungie.appVersion` was set.") }

            var req = URLRequest(url: endpoint)
            req.addValue("Fabled/\(appVersion) AppId/\(appId) (+https://github.com/nathanhosselton/Fabled;nathanhosselton@gmail.com)", forHTTPHeaderField: "User-Agent")
            req.addValue(key, forHTTPHeaderField: "X-API-Key")
            return req
        }

        private var endpoint: URL {
            var comps = URLComponents()
            comps.scheme = "https"
            comps.host = "www.bungie.net"

            let basePath = "/Platform/Destiny2"

            switch self {
            case .getPlayer(let player, let platform):
                comps.path = basePath + "/\(platform.rawValue)/Profile/\(player)"
                comps.queryItems = [URLQueryItem(name: "components", value: Player.Components.forFabled.asQueryString)]

            case .getFindPlayer(let query, let platform):
                comps.path = basePath + "/SearchDestinyPlayer/\(platform.rawValue)/\(query)/"

            case .getCompetitiveHistory(let characterId, let playerId, let platform):
                comps.path = basePath + "/\(platform.rawValue)/Account/\(playerId)/Character/\(characterId)/Stats/Activities/"
                comps.queryItems = [URLQueryItem(name: "mode", value: "69")]
            }

            guard let url = comps.url else { fatalError("Fabled: What did I typo\n" + #file + "\n" + #function) }

            return url
        }

        //MARK: API Response

        struct Error: Decodable {
            /// The Bungie.net API error code
            let ErrorCode: Code
            /// Unused currently.
            let ThrottleSeconds: Int
            /// Unused currently.
            let ErrorStatus: String
            /// Unused currently.
            let Message: String
            /// Unused currently.
            let MessageData: MessageData

            enum Code: Int, Decodable {
                case none, success
                case systemDisabled = 5
                case other //we don't care about any others right now
            }
        }

        /// Unused currently.
        struct MessageData: Decodable
        {}
    }

    /// A type representing the available platforms for Destiny 2.
    public enum Platform: Int {
        case none, xbox, psn, steam

        /// Internal use
        /// - Warning: Only valid for search queries.
        case all = -1

        /// The display name of the platform.
        public var name: String {
            switch self {
            case .xbox: return "XBOX"
            case .psn: return "PSN"
            case .steam: return "STEAM"
            default: return ""
            }
        }

        public typealias RawValue = Int

        public init(rawValue: Int?) {
            guard let raw = rawValue else { self = .none; return }
            self = Platform(rawValue: raw) ?? .none
        }
    }
}

import PMKFoundation

extension Bungie {

    //MARK: API Request

    static func send(_ request: URLRequest) -> Promise<(data: Data, response: URLResponse)> {
        return firstly {
            URLSession.shared.dataTask(.promise, with: request)
        }.then { data, resp -> Promise<(data: Data, response: URLResponse)> in
            // Check if Bungie.net is currently down before checking other errors or forwarding data to caller.
            if let error = try? Bungie.decoder.decode(API.Error.self, from: data), error.ErrorCode == .systemDisabled {
                throw Bungie.Error.systemDisabledForMaintenance
            }
            return Promise.value((data, resp)).validate()
        }
    }
}

private extension Player {
    enum Components: String {
        case none = "0"
        case profiles = "100"
        case vendorReceipts = "101"
        case profileInventories = "102"
        case profileCurrencies = "103"
        case profileProgression = "104"
        case characters = "200"
        case characterInventories = "201"
        case characterProgressions = "202"
        case characterRenderData = "203"
        case characterActivities = "204"
        case characterEquipment = "205"
        case itemInstances = "300"
        case itemObjectives = "301"
        case itemPerks = "302"
        case itemRenderData = "303"
        case itemStats = "304"
        case itemSockets = "305"
        case itemTalentGrids = "306"
        case itemCommonData = "307"
        case itemPlugStates = "308"
        case vendors = "400"
        case vendorCategories = "401"
        case vendorSales = "402"
        case kiosks = "500"
        case currencyLookups = "600"
        case presentationNodes = "700"
        case collectibles = "800"
        case records = "900"

        static var forFabled: [Components] {
            return [.profiles, .characterProgressions]
        }
    }
}

private extension Array where Element == Player.Components {
    var asQueryString: String {
        return map({ $0.rawValue }).joined(separator: ",")
    }
}
