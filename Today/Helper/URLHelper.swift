//
//  URLHelper.swift
//  Today
//
//  Created by Ethan John Lagera on 7/1/26.
//
// Source - https://stackoverflow.com/a/48566887
// Posted by gheclipse, modified by community. See post 'Timeline' for change history
// Retrieved 2026-07-01, License - CC BY-SA 4.0

import Foundation

extension URL {
    // MARK: - File Size
    var attributes: [FileAttributeKey : Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: path)
        } catch let error as NSError {
            print("FileAttribute error: \(error)")
        }
        return nil
    }
    
    var fileSize: UInt64 {
        return attributes?[.size] as? UInt64 ?? UInt64(0)
    }
    
    var fileSizeString: String {
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
    
    var creationDate: Date? {
        return attributes?[.creationDate] as? Date
    }
    
    // MARK: - Directory Size
    func directoryTotalSize() -> UInt64 {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return 0
        }
        
        if !isDirectory.boolValue {
            return fileSize
        }
        
        var total: UInt64 = 0
        
        if let enumerator = FileManager.default.enumerator(
            at: self,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let itemURL as URL in enumerator {
                do {
                    let resourceValues = try itemURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                    if resourceValues.isRegularFile == true, let size = resourceValues.fileSize {
                        total += UInt64(size)
                    }
                } catch {
                    continue
                }
            }
        }
        
        return total
    }
    
    var directorySizeString: String {
        ByteCountFormatter.string(fromByteCount: Int64(directoryTotalSize()), countStyle: .file)
    }
    
    func directoryTotalSizeAsync() async -> UInt64 {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let size = self.directoryTotalSize()
                continuation.resume(returning: size)
            }
        }
    }
    
    func directorySizeStringAsync() async -> String {
        await ByteCountFormatter.string(fromByteCount: Int64(directoryTotalSizeAsync()), countStyle: .file)
    }
}
