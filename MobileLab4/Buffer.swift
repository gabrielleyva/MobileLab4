//
//  Buffer.swift
//  MobileLab4
//
//  Created by Mandar Phadate on 10/14/17.
//  Copyright © 2017 Leyva_Phadate. All rights reserved.
//

import UIKit

class Buffer: NSObject {
    var data:[Float] = []
    var index = 0
    let size:Int
    
    override init() {
        self.size = 450 // Default size
    }
    
    init (with size:Int){
        self.size = size
    }
    
    func add(point: Float) {
        if (self.index < self.size){
            self.data.append(point)
            self.index += 1
        }else{
            self.data.removeFirst()
            self.data.append(point)
        }
    }
    
    func getData() -> [Float] {
        return self.data
    }
    
    func getBufferCount() -> Int {
        return self.data.count
    }
    
    func reset() {
        self.data.removeAll()
        self.index = 0
        print("Databuffer reset")
    }
    
}
