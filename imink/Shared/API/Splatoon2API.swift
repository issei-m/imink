//
//  Splatoon2API.swift
//  imink
//
//  Created by Jone Wang on 2020/9/4.
//

import Foundation

enum Splatoon2API {
    case battleInformation
    case result(battleNumber: String)
    case schedules
    case salmonRunSchedules
    case records
    case nicknameAndIcon(id: String)
    case activeFestivals
    case jobOverview
    case job(id: Int)
}

extension Splatoon2API: APITargetType {
    
    static let host = URL(string: "https://app.splatoon2.nintendo.net")!
    
    var baseURL: URL { Splatoon2API.host.appendingPathComponent("/api") }
    
    var path: String {
        switch self {
        case .battleInformation:
            return "/results"
        case .result(let battleNumber):
            return "/results/\(battleNumber)"
        case .schedules:
            return "/schedules"
        case .salmonRunSchedules:
            return "/coop_schedules"
        case .records:
            return "/records"
        case .nicknameAndIcon:
            return "/nickname_and_icon"
        case .activeFestivals:
            return "/festivals/active"
        case .jobOverview:
            return "coop_results"
        case .job(let id):
            return "coop_results/\(id)"
        }
    }
    
    var method: APIMethod {
        switch self {
        case .battleInformation,
             .result,
             .schedules,
             .salmonRunSchedules,
             .records,
             .nicknameAndIcon,
             .activeFestivals,
             .jobOverview,
             .job:
            return .get
        }
    }
    
    var headers: [String : String]? {
        if let user = AppUserDefaults.shared.user {
            return ["Cookie": "iksm_session=\(user.iksmSession)"]
        }

        return nil
    }
    
    var querys: [(String, String?)]? {
        switch self {
        case .nicknameAndIcon(let id):
            return [("id", id)]
        default:
            return nil
        }
    }
    
    var data: MediaType? {
        return nil
    }
}
