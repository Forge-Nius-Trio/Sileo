//
//  DependencyResolverAccelerator.swift
//  Sileo
//
//  Created by CoolStar on 1/19/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import Foundation

class DependencyResolverAccelerator {
    public static let shared = DependencyResolverAccelerator()
    private var dependencyLock = DispatchSemaphore(value: 1)
    private var partialRepoList: [URL: Set<Package>] = [:]
    private var packageList: Set<Package> = []
    
    private var preflightedRepoList: [URL: Set<Package>] = [:]
    private var preflightedRepos = false
    
    public func preflightInstalled() {
        dependencyLock.wait()
        
        preflightedRepos = false
        
        partialRepoList = [:]
        for depPackage in PackageListManager.shared.installedPackages ?? [] {
            getDependenciesInternal(package: depPackage)
        }
        
        preflightedRepoList = partialRepoList
        partialRepoList = [:]
        
        preflightedRepos = true
        dependencyLock.signal()
    }
    
    private var depResolverPrefix: URL {
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        let listsURL = FileManager.default.documentDirectory.appendingPathComponent("sileolists")
        if !listsURL.dirExists {
            try? FileManager.default.createDirectory(at: listsURL, withIntermediateDirectories: true)
        }
        return listsURL
        #elseif targetEnvironment(macCatalyst)
        return URL(fileURLWithPath: "/opt/procursus/var/lib/apt/sileolists")
        #else
        return URL(fileURLWithPath: "/var/lib/apt/sileolists")
        #endif
    }
    
    public func getDependencies(install: [DownloadPackage], remove: [DownloadPackage]) {
        if !preflightedRepos {
            preflightInstalled()
        }
        PackageListManager.shared.waitForReady()
        dependencyLock.wait()
        partialRepoList = preflightedRepoList
        
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        #elseif targetEnvironment(macCatalyst)
        spawn(command: "/bin/mkdir", args: ["mkdir", "-p", "/opt/procursus/var/lib/apt/sileolists"])
        spawn(command: "/bin/chown", args: ["chown", "-R", "\(NSUserName()):staff", "/opt/procursus/var/lib/apt/sileolists"])
        spawn(command: "/bin/chmod", args: ["chmod", "-R", "0755", "/opt/procursus/var/lib/apt/sileolists"])
        #else
        spawnAsRoot(args: ["/usr/bin/mkdir", "-p", "/var/lib/apt/sileolists"])
        spawnAsRoot(args: ["/usr/bin/chown", "-R", "mobile:mobile", "/var/lib/apt/sileolists"])
        spawnAsRoot(args: ["/usr/bin/chmod", "-R", "0755", "/var/lib/apt/sileolists"])
        #endif
        
        guard let filePaths = try? FileManager.default.contentsOfDirectory(at: depResolverPrefix, includingPropertiesForKeys: nil, options: []) else {
            return
        }
        NSLog("[Sileo] filePaths = \(filePaths)")
        for filePath in filePaths {
            try? FileManager.default.removeItem(at: filePath.aptUrl)
        }
        
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        #elseif targetEnvironment(macCatalyst)
        spawn(command: "/bin/chown", args: ["chown", "-R", "\(NSUserName()):staff", "/opt/procursus/var/lib/apt/lists"])
        spawn(command: "/bin/chmod", args: ["chmod", "-R", "0755", "/opt/procursus/var/lib/apt/lists"])
        let (test, test2, test3) = spawn(command: "/bin/cp", args: ["cp", "/opt/procursus/var/lib/apt/lists/*Release", "/opt/procursus/var/lib/apt/sileolists/"])
        NSLog("[Sileo] Attempt to copy \(test) \(test2) \(test3)")
        #else
        spawnAsRoot(args: ["/usr/bin/cp", "/var/lib/apt/lists/*Release", "/var/lib/apt/sileolists/"])
        #endif
        
        for package in install {
            getDependenciesInternal2(package: package.package)
        }
        
        for package in remove {
            getDependenciesInternal2(package: package.package)
        }
        
        let resolverPrefix = depResolverPrefix
        for (sourcesFile, packages) in partialRepoList {
            if sourcesFile.lastPathComponent == "status" {
                continue
            }
            let newSourcesFile = resolverPrefix.appendingPathComponent(sourcesFile.lastPathComponent)
            
            var sourcesData = Data()
            for package in packages {
                guard let packageData = package.rawData else {
                    continue
                }
                sourcesData.append(packageData)
            }
            try? sourcesData.write(to: newSourcesFile.aptUrl)
        }
        
        partialRepoList.removeAll()
        dependencyLock.signal()
    }
    
    private func getDependenciesInternal(package: Package) {
        for packageVersion in package.allVersions {
            getDependenciesInternal2(package: packageVersion)
        }
    }
    
    private func getDependenciesInternal2(package: Package) {
        guard let sourceFileURL = package.sourceFileURL?.aptUrl else {
            return
        }
        if partialRepoList[sourceFileURL] == nil {
            partialRepoList[sourceFileURL] = Set<Package>()
        }
        if partialRepoList[sourceFileURL]?.contains(package) ?? false {
            return
        }
        partialRepoList[sourceFileURL]?.insert(package)
        
        let packageKeys = ["depends", "pre-depends", "conflicts", "replaces"]
        
        for packageKey in packageKeys {
            if let packagesData = package.rawControl[packageKey] {
                let packageIds = parseDependsString(depends: packagesData)
                for repo in RepoManager.shared.repoList {
                    for packageId in packageIds {
                        if let depPackage = repo.packagesDict?[packageId] {
                            getDependenciesInternal(package: depPackage)
                        }
                    }
                    
                    for depPackage in repo.packagesProvides ?? [] {
                        var matchedPkg = false
                        for packageId in packageIds {
                            if depPackage.rawControl["provides"]?.contains(packageId) ?? false {
                                matchedPkg = true
                                break
                            }
                        }
                        if matchedPkg {
                            getDependenciesInternal(package: depPackage)
                        }
                    }
                }
            }
        }
    }
    
    private func parseDependsString(depends: String) -> [String] {
        let parts = depends.components(separatedBy: CharacterSet(charactersIn: ",|"))
        var packageIds: [String] = []
        for part in parts {
            let newPart = part.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression).replacingOccurrences(of: " ", with: "")
            packageIds.append(newPart)
        }
        return packageIds
    }
}
