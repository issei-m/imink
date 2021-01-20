//
//  DBJob.swift
//  imink
//
//  Created by Jone Wang on 2021/1/20.
//

import Foundation
import GRDB
import Combine
import os

struct DBJob: Identifiable {
    
    // MARK: Column
    
    var id: Int64?
    var sp2PrincipalId: String
    var jobId: Int
    var json: String
}

extension DBJob: Codable, FetchableRecord, MutablePersistableRecord {
    
    // Table name
    static let databaseTableName = "job"
    
    // Define database columns from CodingKeys
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let sp2PrincipalId = Column(CodingKeys.sp2PrincipalId)
        static let jobId = Column(CodingKeys.jobId)
        static let json = Column(CodingKeys.json)
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

extension AppDatabase {
    
    // MARK: Writes
    
    func removeAllJobs() {
        dbQueue.asyncWrite { db in
            try DBJob.deleteAll(db)
        } completion: { _, error in
            if case let .failure(error) = error {
                os_log("Database Error: [removeAllJobs] \(error.localizedDescription)")
            }
        }
    }
    
    func saveJob(data: Data) {
        guard let currentUser = AppUserDefaults.shared.user,
              let jsonString = String(data: data, encoding: .utf8),
              let job = jsonString.decode(Job.self) else {
            return
        }
        
        dbQueue.asyncWrite { db in
            if try DBRecord.filter(
                DBRecord.Columns.sp2PrincipalId == currentUser.sp2PrincipalId &&
                    DBRecord.Columns.battleNumber == job.jobId
            ).fetchCount(db) > 0 {
                return
            }
            
            var record = DBJob(
                sp2PrincipalId: currentUser.sp2PrincipalId,
                jobId: job.jobId,
                json: jsonString)
            try record.insert(db)
        } completion: { _, error in
            if case let .failure(error) = error {
                os_log("Database Error: [saveJob] \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: Reads
    
    func unsynchronizedJobIds(with jobIds: [Int]) -> [Int] {
        guard let currentUser = AppUserDefaults.shared.user else {
            return []
        }
        
        return dbQueue.read { db in
            let alreadyExistsRecords = try! DBJob.filter(
                DBJob.Columns.sp2PrincipalId == currentUser.sp2PrincipalId &&
                    jobIds.contains(DBJob.Columns.jobId)
            )
            .fetchAll(db)
            
            let alreadyExistsIds = alreadyExistsRecords.map { $0.jobId }
            let unsynchronizedIds = Array(Set(jobIds).subtracting(Set(alreadyExistsIds)))
            
            return unsynchronizedIds
        }
    }
}
