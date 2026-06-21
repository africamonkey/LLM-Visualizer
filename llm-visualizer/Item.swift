//
//  Item.swift
//  llm-visualizer
//
//  Created by Africamonkey on 2026/6/21.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
