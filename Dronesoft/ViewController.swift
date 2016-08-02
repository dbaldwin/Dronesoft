//
//  ViewController.swift
//  Dronesoft
//
//  Created by Dennis Baldwin on 7/30/16.
//  Copyright © 2016 Unmanned Airlines, LLC. All rights reserved.
//

import UIKit
import GoogleMaps

class ViewController: UIViewController, GMSMapViewDelegate {
    
    var markers = [Int: GMSMarker]()
    
    var polygon : GMSPolygon = GMSPolygon()

    @IBOutlet weak var mapView: GMSMapView!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let camera = GMSCameraPosition.cameraWithLatitude(30.3074625, longitude: -98.0335949, zoom: 14.0)
        mapView.camera = camera
        mapView.myLocationEnabled = true
        mapView.mapType = kGMSTypeHybrid
        mapView.myLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.delegate = self


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
        polygon.map = mapView
     
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
        polygon.map = mapView
        
    }

    // Clear the map
    @IBAction func clearMap(sender: AnyObject) {
        mapView.clear()
        markers = [:]
    }
}

