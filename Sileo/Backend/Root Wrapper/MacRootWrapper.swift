//
//  MacRootWrapper.swift
//  Sileo
//
//  Created by Amy on 05/04/2021.
//  Copyright © 2021 CoolStar. All rights reserved.
//

#if targetEnvironment(macCatalyst)
import Foundation

class MacRootWrapper {
    static let shared = MacRootWrapper()
    
    init() {
        let bundleFileName = "SileoRootHelper.bundle"
        let className = "LaunchAsRoot"
        guard let bundleURL = Bundle.main.builtInPlugInsURL?
                                    .appendingPathComponent(bundleFileName),
              let bundle = Bundle(url: bundleURL),
              let pluginClass = bundle.classNamed(className) as? LaunchAsRootProtocol.Type else { fatalError("oof") }
        let helper = pluginClass.init()
        helper?.launchAsRoot()
    }
}
#endif
