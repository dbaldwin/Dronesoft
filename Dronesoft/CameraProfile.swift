//
//  CameraProfile.swift
//  Dronesoft
//
//  Created by Zhongtian Chen on 8/13/16.
//  Copyright © 2016 Unmanned Airlines, LLC. All rights reserved.
//

import UIKit

class CameraProfile: NSObject {
    
    struct FOV {
        var vertical : Int!
        var horizontal : Int!
        var x : Int {
            get {
                return horizontal
            }
        }
        var y : Int {
            get {
                return vertical
            }
        }
    }
    
    var name : String = ""
    var fieldOfView : FOV!
    
    
    override init() {
        fieldOfView = FOV(vertical: 20, horizontal: 50)
    }

}
