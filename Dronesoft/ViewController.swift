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

class ViewController: UIViewController, GMSMapViewDelegate, UITextFieldDelegate, DJISDKManagerDelegate, DJIFlightControllerDelegate, DJIMissionManagerDelegate, SurveyMissionDelegate {
    
    var surveyMission : SurveyMission!
    
    let aircraftMarker = GMSMarker()
    
    @IBOutlet weak var mapView: GMSMapView!
    
    @IBOutlet weak var addressField: UITextField!
    
    @IBOutlet weak var infoView: UIView!
    
    @IBOutlet weak var markerLabel: UILabel!
    
    @IBOutlet weak var acreLabel: UILabel!
    
    @IBOutlet weak var aircraftLabel: UILabel!
    
    @IBOutlet weak var firmwareLabel: UILabel!
    
    @IBOutlet weak var sdkLabel: UILabel!
    
    @IBOutlet weak var satelliteLabel: UILabel!
    
    var missionManager : DJIMissionManager? = nil
    
    // Hide the status bar as not to interfere with the info view
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        surveyMission = SurveyMission(delegate: self)
        
        // Set initial location of the map
        let camera = GMSCameraPosition.cameraWithLatitude(30.3054, longitude: -98.032, zoom: 16.5)
        mapView.camera = camera
        mapView.myLocationEnabled = true
        mapView.mapType = kGMSTypeHybrid
        mapView.myLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.settings.compassButton = true
        mapView.padding = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 200)
        mapView.delegate = self
        
        // Set the address field delegate
        addressField.delegate = self
        
        // Give a little transparency to the info view
        infoView.alpha = 0.90
        
        /// Register our app with DJI's servers
        DJISDKManager.registerApp("e5dc7da3664c1a1f0daa4e46", withDelegate: self)
        
        // Display the SDK version
        sdkLabel.text = DJISDKManager.getSDKVersion()
        
        // Initialize the aircraft marker
        aircraftMarker.icon = UIImage(named: "Aircraft")
        aircraftMarker.groundAnchor = CGPointMake(0.5, 0.5);
        aircraftMarker.position = CLLocationCoordinate2D(latitude: 30.305, longitude: -98.032)
        aircraftMarker.map = mapView
        
        // Setting up the mission manager
        self.missionManager = DJIMissionManager.sharedInstance()
        self.missionManager!.delegate = self
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // MARK: - GMSMapViewDelegate
    
    // When a user taps on the map we add a marker
    func mapView(mapView: GMSMapView, didTapAtCoordinate coordinate: CLLocationCoordinate2D) {
        surveyMission.addMarkerToPolygon(atLocation: coordinate)//.roundCoordinateToPrecision(8))
    }
    
    // Marker dragging code
    func mapView(mapView: GMSMapView, didEndDraggingMarker marker: GMSMarker) {
        surveyMission.updatePolygon()
    }
    
    // Check for polygon taps
    func mapView(mapView: GMSMapView, didTapOverlay overlay: GMSOverlay) {
        surveyMission.computeFlightPath(EntryCorner.TopLeft)
    }
    
    
    // MARK: - UITextFieldDelegate
    
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
    
    
    // MARK: - Mission Planning
    
    // Clear the map
    @IBAction func clearMap(sender: AnyObject) {
        mapView.clear()
        surveyMission.clear()
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
    
    func surveyMissionNewMarkerAdded(markers: [GMSMarker]) {
        markers.last?.map = mapView
        surveyMission.updatePolygon()
    }
    
    func surveyMissionPolygonUpdated(polygon: GMSPolygon) {
        surveyMission.polygon.map = mapView
        
        markerLabel.text = "\(surveyMission.markers.count)"
        if (surveyMission.markers.count > 2) {
            let area = GMSGeometryArea(surveyMission.polygonPath)
            let acres = area * 0.00024711
            
            acreLabel.text = String(format: "%.02f", acres)
        }
    }
    
    func surveyMissionFlightPathUpdated(flightPath: GMSPolyline) {
        flightPath.map = mapView
        aircraftMarker.position = (flightPath.path?.coordinateAtIndex(0))!
        aircraftMarker.map = mapView
        //TODO: Update flightpath related UI items.
    }
    
    // MARK: - DJISDKManagerDelegate
    
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
    
    
    // MARK: - DJIFlightControllerDelegate
    
    func flightController(fc: DJIFlightController, didUpdateSystemState state: DJIFlightControllerCurrentState) {
        
        aircraftMarker.position = state.aircraftLocation
        
        // Set the heading of the marker
        let heading = state.attitude.yaw
        heading >= 0 ? heading : heading + 360.0
        aircraftMarker.rotation = heading
        
        satelliteLabel.text = "\(state.satelliteCount)"
        
    }
    
    
    // MARK: - Mission methods
    
    @IBAction func confirmStartMission(sender: AnyObject) {
        
        // Make sure there are at least 2 waypoints
        
        // Make sure there are enough sats
        
        // For now hardcode speed and altitude
        
        let refreshAlert = UIAlertController(title: "Confirm", message: "Are you ready to start the mission?", preferredStyle: UIAlertControllerStyle.Alert)
        
        
        refreshAlert.addAction(UIAlertAction(title: "Yes", style: .Default, handler: { (action: UIAlertAction!) in
            
            self.uploadAndStartMission()
            
        }))
        
        refreshAlert.addAction(UIAlertAction(title: "No", style: .Cancel, handler: { (action: UIAlertAction!) in
            
            // Do nothing when confirmation is canceled
            
        }))
        
        presentViewController(refreshAlert, animated: true, completion: nil)
        
    }
    
    // Build up the waypoint mission and then takeoff
    func uploadAndStartMission () {
        
        logDebug("Upload and start mission")
        
        let mission : DJIWaypointMission = DJIWaypointMission()
        mission.autoFlightSpeed = 8 // m/s
        mission.finishedAction = DJIWaypointMissionFinishedAction.GoHome
        mission.headingMode = DJIWaypointMissionHeadingMode.Auto
        mission.flightPathMode = DJIWaypointMissionFlightPathMode.Normal
        
        // Enumerate the markers and create waypoints
        for marker in surveyMission.markers {
            
            let waypoint : DJIWaypoint = DJIWaypoint()
            waypoint.coordinate = marker.position
            waypoint.altitude = 30
            mission.addWaypoint(waypoint)
            
            logDebug("Waypoint: \(waypoint.coordinate.latitude), \(waypoint.coordinate.longitude)")
            
        }
        
        // Upload the mission and then execute it
        self.missionManager!.prepareMission(mission, withProgress: nil, withCompletion:
            {[weak self] (error: NSError?) -> Void in
                if error == nil {
                    self?.missionManager!.startMissionExecutionWithCompletion({ [weak self] (error: NSError?) -> Void in
                        if error != nil {
                            print("Error starting mission" + "abcd")
                            self!.logDebug("Error starting mission: " + (error?.description)!)
                        
                        }
                    })
                } else {
                    print("Error preparing mission")
                    self!.logDebug("Error preparing mission: " + (error?.description)!)
                }
            
            })
    }
    
    
    // MARK: - Utilities: Logging
    
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

