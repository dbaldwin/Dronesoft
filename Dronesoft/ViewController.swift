//
//  ViewController.swift
//  Dronesoft
//
//  Created by Dennis Baldwin on 7/30/16.
//  Copyright © 2016 Unmanned Airlines, LLC. All rights reserved.
//

import UIKit
import GoogleMaps
import DJISDK

class ViewController: UIViewController, GMSMapViewDelegate, UITextFieldDelegate, DJISDKManagerDelegate, DJIFlightControllerDelegate {
    
    var markers = [Int: GMSMarker]()
    
    let aircraftMarker = GMSMarker()
    
    var polygon : GMSPolygon = GMSPolygon()

    @IBOutlet weak var mapView: GMSMapView!
    
    @IBOutlet weak var addressField: UITextField!
    
    @IBOutlet weak var infoView: UIView!
    
    @IBOutlet weak var markerLabel: UILabel!
    
    @IBOutlet weak var acreLabel: UILabel!
    
    @IBOutlet weak var aircraftLabel: UILabel!
    
    @IBOutlet weak var firmwareLabel: UILabel!
    
    @IBOutlet weak var sdkLabel: UILabel!
    
    @IBOutlet weak var satelliteLabel: UILabel!
    
    var missionTypeIndex : Int = 0
    
    // Hide the status bar as not to interfere with the info view
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set initial location of the map
        let camera = GMSCameraPosition.cameraWithLatitude(30.3074625, longitude: -98.0335949, zoom: 14.0)
        mapView.camera = camera
        mapView.myLocationEnabled = true
        mapView.mapType = kGMSTypeHybrid
        mapView.myLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.delegate = self
        
        // Set the address field delegate
        addressField.delegate = self
        
        // Give a little transparency to the info view
        infoView.alpha = 0.85
        
        /// Register our app with DJI's servers
        DJISDKManager.registerApp("e5dc7da3664c1a1f0daa4e46", withDelegate: self)
        
        // Display the SDK version
        sdkLabel.text = DJISDKManager.getSDKVersion()
        
        // Initialize the aircraft marker
        aircraftMarker.icon = UIImage(named: "Aircraft")
        aircraftMarker.groundAnchor = CGPointMake(0.5, 0.5);
        aircraftMarker.position = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        aircraftMarker.map = mapView

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: GMSMapViewDelegate
    
    // When a user taps on the map we add a marker
    func mapView(mapView: GMSMapView, didTapAtCoordinate coordinate: CLLocationCoordinate2D) {
        
        // Create a new marker and append it to the dictionary
        let index = markers.count + 1
        let newMarker = GMSMarker()
        newMarker.position = coordinate
        newMarker.map = mapView
        newMarker.draggable = true
        newMarker.userData = index
        newMarker.title = "Marker " + String(index)
        markers[index] = newMarker
        
        // Initalize the polygon rect
        let rect = GMSMutablePath()
        
        // Enumerate the dictionary and build the poly rect
        for(_, value) in markers {
            
            // Append the marker position to the polygon rect
            rect.addCoordinate(value.position)
            
        }
        
        // Clear the polygon off the map
        polygon.map = nil
        
        // Draw the polygon on the map
        polygon = GMSPolygon(path: rect)
        polygon.fillColor = UIColor(red: 0, green: 0, blue: 1.0, alpha: 0.25);
        polygon.strokeColor = UIColor.whiteColor()
        polygon.strokeWidth = 2
        polygon.tappable = true
        polygon.map = mapView
        
        // Update marker count
        markerLabel.text = String(markers.count)
        
        // Update acreage calculation
        if (rect.count() > 2) {
            
            let area = GMSGeometryArea(rect)
            let acres = area * 0.00024711
            
            acreLabel.text = String(format: "%.02f", acres)
            
        }
     
    }
    
    // TODO: Refactor redundant code below
    // Marker dragging code
    func mapView(mapView: GMSMapView, didEndDraggingMarker marker: GMSMarker) {
        
        // Update the marker's position in the dictionary
        let index = marker.userData as? Int
        let oldMarker: GMSMarker = markers[index!]!
        oldMarker.position = marker.position
        
        // Initalize the polygon rect
        let rect = GMSMutablePath()
        
        for (_, value) in markers {
            
            // Append the marker position to the polygon rect
            rect.addCoordinate(value.position)
            
        }
        
        // Clear the polygon off the map
        polygon.map = nil
        
        // Redraw the polygon
        polygon = GMSPolygon(path: rect)
        polygon.fillColor = UIColor(red: 0, green: 0, blue: 1.0, alpha: 0.25);
        polygon.strokeColor = UIColor.whiteColor()
        polygon.strokeWidth = 2
        polygon.tappable = true
        polygon.map = mapView
        
        // Update marker count
        markerLabel.text = String(markers.count)
        
        // Update acreage calculation
        if (rect.count() > 2) {
            
            let area = GMSGeometryArea(rect)
            let acres = area * 0.00024711
            
            acreLabel.text = String(format: "%.02f", acres)
            
        }
        
    }
    
    // Check for polygon taps
    func mapView(mapView: GMSMapView, didTapOverlay overlay: GMSOverlay) {
        
        // Doing nothing at the moment
        
        
    }
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        addressField.resignFirstResponder()
        
        // Forward geocode the address and recenter the map
        CLGeocoder().geocodeAddressString(addressField.text!, completionHandler: { (placemarks, error) in
            if error != nil {
                print(error)
                return
            }
            if placemarks?.count > 0 {
                let placemark = placemarks?[0]
                let location = placemark?.location
                let coordinate = location?.coordinate
                
                self.mapView.animateToLocation(coordinate!)
                
            }
        })
        
        return true
    }
    
    // MARK: DJISDKManagerDelegate
    func sdkManagerDidRegisterAppWithError(error: NSError?) {
        
        guard error == nil  else {
            print("Error:\(error!.localizedDescription)")
            return
        }
        
        // Setup web based logging
        DJISDKManager.enableRemoteLoggingWithDeviceID("1", logServerURLString: "http://10.0.1.10:4567")
        
        #if arch(i386) || arch(x86_64)
            //Simulator
            DJISDKManager.enterDebugModeWithDebugId("10.128.129.59")
        #else
            //Device
            DJISDKManager.startConnectionToProduct()
        #endif
        
    }
    
    func sdkManagerProductDidChangeFrom(oldProduct: DJIBaseProduct?, to newProduct: DJIBaseProduct?) {
        
        guard let newProduct = newProduct else
        {
            logDebug("No product connected")
            aircraftLabel.text = "Disconnected"
            return
        }
        
        aircraftLabel.text = newProduct.model
        
        // Updates the product's model
        if let oldProduct = oldProduct {
            logDebug("Product changed from: \(oldProduct.model) to \((newProduct.model)!)")
            aircraftLabel.text = newProduct.model
        }
        
        // Firmware version
        newProduct.getFirmwarePackageVersionWithCompletion{ (version:String?, error:NSError?) -> Void in
            self.logDebug("Firmware package version is: \(version ?? "Unknown")")
            self.firmwareLabel.text = version
        }
        
        //Updates the product's connection status
        logDebug("Product connected")
        
        // Setup the flight controller delegate
        if (newProduct is DJIAircraft) {
            
            let aircraft: DJIAircraft = newProduct as! DJIAircraft
            aircraft.flightController?.delegate = self
            
        }
        
    }
    
    // MARK: Map functions

    // Clear the map
    @IBAction func clearMap(sender: AnyObject) {
        mapView.clear()
        markers = [:]
        markerLabel.text = "0"
        acreLabel.text = "0"
        
    }

    
    // Forward geocoding for a user to enter a city, zip, street and center the map
    func forwardGeocoding(address: String) {
        CLGeocoder().geocodeAddressString(address, completionHandler: { (placemarks, error) in
            if error != nil {
                print(error)
                return
            }
            if placemarks?.count > 0 {
                let placemark = placemarks?[0]
                let location = placemark?.location
                let coordinate = location?.coordinate
                print("\nlat: \(coordinate!.latitude), long: \(coordinate!.longitude)")
            }
        })
    }
    
    // MARK: DJIFlightControllerDelegate
    func flightController(fc: DJIFlightController, didUpdateSystemState state: DJIFlightControllerCurrentState) {
        
        aircraftMarker.position = state.aircraftLocation
        
        // Set the heading of the marker
        let heading = state.attitude.yaw
        heading >= 0 ? heading : heading + 360.0
        aircraftMarker.rotation = heading
        
        satelliteLabel.text = String(state.satelliteCount)
        
        /*self.currentState = state
        self.aircraftLocation = state.aircraftLocation
        if CLLocationCoordinate2DIsValid(state.aircraftLocation) {
            let heading: Double = state.attitude.yaw*M_PI/180.0
            djiMapView!.updateAircraftLocation(state.aircraftLocation, withHeading: heading)
            
        }
        if CLLocationCoordinate2DIsValid(state.homeLocation) {
            djiMapView!.updateHomeLocation(state.homeLocation)
        }*/
    }
    
    // MARK: Logging methods
    func logDebug<T>(object: T?, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        let logText = convertToString(object)
        DJIRemoteLogger.logWithLevel(.Debug, file: file.stringValue, function: function.stringValue, line: line, string: logText)
    }
    
    func convertToString<T>(objectOpt: T?) -> String {
        if let object = objectOpt
        {
            switch object
            {
            case let error as NSError:
                let localizedDesc = error.localizedDescription
                if !localizedDesc.isEmpty { return "\(error.domain) : \(error.code) : \(localizedDesc)" }
                return "<<\(error.localizedDescription)>> --- ORIGINAL ERROR: \(error)"
            case let nsobject as NSObject:
                if nsobject.respondsToSelector(#selector(NSObject.debugDescription as () -> String)) {
                    return nsobject.debugDescription
                }
                else
                {
                    return nsobject.description
                }
            default:
                return "\(object)"
            }
        }
        else
        {
            return "nil"
        }
        
    }
    
    
}

