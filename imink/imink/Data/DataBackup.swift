//
//  DataBackup.swift
//  imink
//
//  Created by Jone Wang on 2021/6/3.
//

import Foundation
import Combine
import Zip

enum DataBackupError: Error {
    case unknownError
    case databaseWriteError
    case invalidDirectoryStructure
}

extension DataBackupError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unknownError:
            return "Unknown error"
        case .databaseWriteError:
            return "Database write error"
        case .invalidDirectoryStructure:
            return "Invalid directory tructure"
        }
    }
}

class DataBackup {
    static let shared = DataBackup()
    
    private let unzipProgressScale = 0.1
    private var importBattlesProgressScale = 0.45
    private var importJobsProgressScale = 0.45
    
    private var unzipProgress: Double = 0
    private var importBattlesProgress: Double = 0
    private var importJobsProgress: Double = 0
    
    private var importError: Error? = nil
    
    private var progressCancellable: AnyCancellable?
}

// MARK: Export

extension DataBackup {
    
    func export(progress: @escaping (Bool, Double, URL?) -> Void) {
        progress(false, 0, nil)
        let queue = DispatchQueue(label: "PackingData")
        queue.async {
            let exportPath = try? self.packingData { value in
                DispatchQueue.main.async {
                    progress(false, value, nil)
                }
            }
            DispatchQueue.main.async {
                progress(true, 1, exportPath)
            }
        }
    }
    
    private func packingData(progress: @escaping (Double) -> Void) throws -> URL {
        
        let fileManager = FileManager()
        let temporaryPath = fileManager.temporaryDirectory
        
        let exportPath = temporaryPath.appendingPathComponent("imink_export")
        if fileManager.fileExists(atPath: exportPath.path) {
            try fileManager.removeItem(at: exportPath)
        }
        
        let zipPath = temporaryPath.appendingPathComponent("imink_export.zip")
        if fileManager.fileExists(atPath: zipPath.path) {
            try fileManager.removeItem(at: zipPath)
        }
        
        let records = AppDatabase.shared.records(count: Int.max)
        let jobs = AppDatabase.shared.jobs(count: Int.max)
        
        let exportTotalCount = records.count + jobs.count
        var exportedCount = 0
        
        // Export battles
        let battlePath = exportPath.appendingPathComponent("battle")
        try fileManager.createDirectory(at: battlePath, withIntermediateDirectories: true, attributes: nil)

        for record in records {
            exportedCount += 1
            progress((Double(exportedCount) / Double(exportTotalCount)) * 0.3)
            
            let filePath = battlePath.appendingPathComponent("\(record.battleNumber).json")
            guard let json = record.json else { continue }
            try json.write(to: filePath, atomically: false, encoding: .utf8)
        }

        // Export jobs
        let salmonRunPath = exportPath.appendingPathComponent("salmonrun")
        try fileManager.createDirectory(at: salmonRunPath, withIntermediateDirectories: true, attributes: nil)

        for job in jobs {
            exportedCount += 1
            progress((Double(exportedCount) / Double(exportTotalCount)) * 0.3)
            
            let filePath = salmonRunPath.appendingPathComponent("\(job.jobId).json")
            guard let json = job.json else { continue }
            try json.write(to: filePath, atomically: false, encoding: .utf8)
        }
        
        try Zip.zipFiles(paths: [exportPath], zipFilePath: zipPath, password: nil, progress: { value in
            progress(0.3 + (value * 0.7))
        })
        
        return zipPath
    }
}

// MARK: Import

extension DataBackup {
    
    var progress: Double {
        unzipProgress * unzipProgressScale +
            importBattlesProgress * importBattlesProgressScale +
            importJobsProgress * importJobsProgressScale
    }
    
    func `import`(url: URL, progress: @escaping (Double, Error?) -> Void) {
        unzipProgress = 0
        importBattlesProgress = 0
        importJobsProgress = 0
        importError = nil
        
        progressCancellable = Timer.publish(every: 0.1, on: .main, in: .default)
            .autoconnect()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let `self` = self else {
                    return
                }
                
                progress(self.progress, self.importError)
                if self.progress == 1 || self.importError != nil {
                    self.progressCancellable?.cancel()
                }
            }
        
        DispatchQueue(label: "import").async {
            do {
                try self.importData(url: url)
            } catch {
                self.importError = DataBackupError.unknownError
            }
        }
    }
    
    private func importData(url: URL) throws {
        let fileManager = FileManager()
        let temporaryPath = fileManager.temporaryDirectory
        let importPath = temporaryPath.appendingPathComponent("import")
        
        do {
            if fileManager.fileExists(atPath: importPath.path) {
                try fileManager.removeItem(at: importPath)
            }
            try fileManager.createDirectory(at: importPath, withIntermediateDirectories: true, attributes: nil)
            
            try Zip.unzipFile(url, destination: importPath, overwrite: true, password: nil, progress: { [weak self] value in
                self?.unzipProgress = value
            })
            
            guard let unzipPath = try fileManager.contentsOfDirectory(
                    at: importPath,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]).first(where: { url in
                        url.lastPathComponent != "__MACOSX" &&
                            !url.lastPathComponent.hasPrefix(".")
                    }) else {
                throw DataBackupError.invalidDirectoryStructure
            }
            
            let battlePath = unzipPath.appendingPathComponent("battle")
            let battleFilePaths = try fileManager.contentsOfDirectory(
                at: battlePath,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles])
                .filter { $0.pathExtension == "json" }

            let needImportBattleIds = AppDatabase.shared.unsynchronizedBattleIds(
                with: battleFilePaths.map { $0.deletingPathExtension().lastPathComponent }
            )

            let battleDatas = battleFilePaths
                .filter { needImportBattleIds.contains($0.deletingPathExtension().lastPathComponent) }
                .map { try? Data(contentsOf: $0) }
                .filter { $0 != nil }
                .map { $0! }

            AppDatabase.shared.saveBattles(datas: battleDatas) { [weak self] value, error in
                self?.importBattlesProgress = value
                if error != nil {
                    self?.importError = DataBackupError.databaseWriteError
                }
            }
            
            let salmonRunPath = unzipPath.appendingPathComponent("salmonrun")
            let salmonRunFilePaths = try fileManager.contentsOfDirectory(
                at: salmonRunPath,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles])
                .filter { $0.pathExtension == "json" }
            
            let needImportJobIds = AppDatabase.shared.unsynchronizedJobIds(
                with: salmonRunFilePaths.map { $0.deletingPathExtension().lastPathComponent }.filter { Int($0) != nil }.map { Int($0)! }
            )
            .map { "\($0)" }
            
            let salmonRunDatas = salmonRunFilePaths
                .filter { needImportJobIds.contains($0.deletingPathExtension().lastPathComponent) }
                .map { try? Data(contentsOf: $0) }
                .filter { $0 != nil }
                .map { $0! }
            
            AppDatabase.shared.saveJobs(datas: salmonRunDatas) { [weak self] value, error in
                self?.importJobsProgress = value
                if error != nil {
                    self?.importError = DataBackupError.databaseWriteError
                }
            }
            
            // Progress
            let allRecordsCount = battleDatas.count + salmonRunDatas.count
            let allRecordsScale = 1 - unzipProgressScale
            importBattlesProgressScale = (Double(battleDatas.count) / Double(allRecordsCount)) * allRecordsScale
            importJobsProgressScale = allRecordsScale - importBattlesProgressScale
        } catch is CocoaError {
            self.importError = DataBackupError.invalidDirectoryStructure
        } catch {
            self.importError = DataBackupError.unknownError
        }
    }
}
