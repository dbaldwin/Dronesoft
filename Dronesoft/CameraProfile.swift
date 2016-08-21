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
        var vertical : Float!
        var horizontal : Float!
        var x : Float {
            get {
                return horizontal
            }
        }
        var y : Float {
            get {
                return vertical
            }
        }
    }
    
    // TODO: GET CORRECT CAMERA PARAMETERS
    // and determine whether to use drone or camera model for parameter "model".
    static var Phantom4CameraProfile : CameraProfile {
        get {
            //incorrect
            return CameraProfile(model: "FC330", fieldOfView: FOV(vertical: 30, horizontal: 40))
        }
    }
    
    static var Phantom34KCameraProfile : CameraProfile {
        get {
            //incorrect
            return CameraProfile(model: "FC330", fieldOfView: FOV(vertical: 30, horizontal: 40))
        }
    }
    
    private(set) var model : String = ""
    private(set) var fieldOfView : FOV!
    
    init(model : String, fieldOfView : FOV) {
        self.model = model
        self.fieldOfView = fieldOfView
    }

}
