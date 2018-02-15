//
//  Blockchain.swift
//  KinEcosystem
//
//  Created by Elazar Yifrach on 11/02/2018.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation
import KinSDK

struct BlockchainProvider: ServiceProvider {
    let url: URL
    let networkId: NetworkId
    
    init(networkId: NetworkId) {
        self.networkId = networkId
        switch networkId {
        case .mainNet:
            self.url = URL(string: "///TODO:///")!
        case .testNet:
            self.url = URL(string: "https://horizon-testnet.stellar.org")!
        default:
            self.url = URL(string: "https://horizon-testnet.stellar.org")!
        }
    }
}

class Blockchain {
    let client: KinClient
    var activated = false
    init(networkId: NetworkId) throws {
        client = try KinClient(provider: BlockchainProvider(networkId: networkId))
        if client.accounts[0] == nil {
            _ = try client.addAccount(with: "")
        }
    }
    
    // TODO: activate with promise
}
