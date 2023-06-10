//
//  MLExperimentsApp.swift
//  MLExperiments
//
//  Created by Yusuf Fayzullin on 07.04.2023.
//

import SwiftUI

@main
struct MLExperimentsApp: App {
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        print("Active")
                    } else if newPhase == .inactive {
                        print("Inactive")
                        UserDefaults.standard.set(true, forKey: "firstRunDone")
                    } else if newPhase == .background {
                        print("Background")
                        UserDefaults.standard.set(true, forKey: "firstRunDone")
                    }
                }
        }
    }
}
