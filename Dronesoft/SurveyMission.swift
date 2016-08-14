//
//  SurveyMission.swift
//  Dronesoft
//
//  Created by Zhongtian Chen on 8/13/16.
//  Copyright © 2016 Unmanned Airlines, LLC. All rights reserved.
//

import UIKit
import CoreLocation
import GoogleMaps

protocol SurveyMissionDelegate {
    func surveyMissionNewMarkerAdded(markers: [GMSMarker])
    func surveyMissionPolygonUpdated(polygon: GMSPolygon)
    func surveyMissionFlightPathUpdated(flightPath: GMSPolyline)
}

enum EntryCorner : String {
    case TopLeft, TopRight, BottomLeft, BottomRight //, AircraftLocation
}

struct Line {
    var pt1, pt2 : CLLocationCoordinate2D
    var x1 : Double {
        get {
            return pt1.longitude
        }
    }
    var x2 : Double {
        get {
            return pt2.longitude
        }
    }
    var y1 : Double {
        get {
            return pt1.latitude
        }
    }
    var y2 : Double {
        get {
            return pt2.latitude
        }
    }
    
    var distanceInMeters : CLLocationDistance {
        get {
            return GMSGeometryDistance(pt1, pt2)
        }
    }
    
    // AX + BY = C
    var coefficients : (Double, Double, Double) {
        get {
            return (y1-y2, x2-x1, x2*y1-x1*y2)
        }
    }
    
    /** solving: ax + by = c
     **          dx + ey = f
     ** Using Cramer's Rule, utilizing determinants.
     */
    func getIntersectionWith(anotherLine line: Line) -> CLLocationCoordinate2D? {
        let (a, b, c) = self.coefficients
        let (d, e, f) = line.coefficients
        
        let determinant = a*e - b*d;
        if(determinant != 0) {
            let x = (c*e - b*f)/determinant;
            let y = (a*f - c*d)/determinant;
            return CLLocationCoordinate2D(latitude: y, longitude: x)
        } else {
            return nil;
        }
    }
}

struct ContainerRect {
    
    static func getContainerRect(coordinates: [CLLocationCoordinate2D]) -> ContainerRect {
        var minLat = 90.0, maxLat = -90.0, minLong = 180.0, maxLong = -180.0
        for coordinate in coordinates {
            if coordinate.latitude < minLat {
                minLat = coordinate.latitude
            }
            if coordinate.latitude > maxLat {
                maxLat = coordinate.latitude
            }
            if coordinate.longitude < minLong {
                minLong = coordinate.longitude
            }
            if coordinate.longitude > maxLong {
                maxLong = coordinate.longitude
            }
        }
        return ContainerRect(minLat: minLat, maxLat: maxLat, minLong: minLong, maxLong: maxLong)
    }
    
    var minLat, maxLat, minLong, maxLong : Double
    var topLeftCornerPt : CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(latitude: maxLat, longitude: minLong)
        }
    }
    var topRightCornerPt : CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(latitude: maxLat, longitude: maxLong)
        }
    }
    var bottomLeftCornerPt : CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(latitude: minLat, longitude: minLong)
        }
    }
    var bottomRightCornerPt : CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(latitude: minLat, longitude: maxLong)
        }
    }
    var horizontalDistance : Double {
        get {
            return ceil(GMSGeometryDistance(bottomLeftCornerPt, bottomRightCornerPt))
        }
    }
    var verticalDistance : Double {
        get {
            return ceil(GMSGeometryDistance(topLeftCornerPt, bottomLeftCornerPt))
        }
    }
}

class SurveyMission: NSObject {
    var markers : [GMSMarker]!
    
    var polygon : GMSPolygon!
    
    var delegate : SurveyMissionDelegate? = nil
    
    private(set) var missionWaypoints : [CLLocationCoordinate2D]! {
        didSet {
            let path : GMSMutablePath = GMSMutablePath()
            for coordinate in missionWaypoints {
                path.addCoordinate(coordinate)
            }
            flightPath.path = path
            delegate?.surveyMissionFlightPathUpdated(flightPath)
        }
    }
    
    private(set) var flightPath : GMSPolyline!
    
    var polygonPath : GMSMutablePath {
        get {
            let path = GMSMutablePath()
            if markers.count == 0 {
                return path
            }
            for marker in markers {
                path.addCoordinate(marker.position)
            }
            return path
        }
    }
    
    init(delegate : SurveyMissionDelegate) {
        markers = [GMSMarker]()
        polygon = GMSPolygon()
        polygon.fillColor = UIColor(red: 0, green: 0, blue: 1.0, alpha: 0.25);
        polygon.strokeColor = UIColor.whiteColor()
        polygon.strokeWidth = 2
        polygon.tappable = true
        flightPath = GMSPolyline()
        flightPath.strokeColor = UIColor.redColor()
        self.delegate = delegate
    }
    
    func addMarkerToPolygon(atLocation coordinate: CLLocationCoordinate2D) {
        // Create a new marker and append it to the dictionary
        let index = markers.count
        let newMarker = GMSMarker()
        newMarker.position = coordinate
        newMarker.draggable = true
        newMarker.userData = index
        newMarker.title = "Marker \(index)"
        markers.append(newMarker)
        
        if let delegate = delegate {
            delegate.surveyMissionNewMarkerAdded(markers)
        }
    }
    
    func updatePolygon() {
        polygon.path = polygonPath
        
        if let delegate = delegate {
            delegate.surveyMissionPolygonUpdated(polygon)
        }
    }
    
    func computeFlightPath(entryCorner : EntryCorner) -> [CLLocationCoordinate2D] {
        if markers.count < 3 {
            missionWaypoints = [CLLocationCoordinate2D]()
            return missionWaypoints
        }
        
        var flightWaypoints = [CLLocationCoordinate2D]()
        
        let markerCoordinates = markers.map { $0.position }
        var polygonLines : [Line] = [Line]()
        for i in 0..<markers.count-1 {
            polygonLines.append(Line(pt1: markers[i].position, pt2: markers[i+1].position))
        }
        polygonLines.append(Line(pt1: markers.last!.position, pt2: markers.first!.position))
        let containerRect : ContainerRect = ContainerRect.getContainerRect(markerCoordinates)
        let gridLineLength : Double = containerRect.horizontalDistance
        let gridVerticalDist : Double = containerRect.verticalDistance
        
        // TODO: GET ACTUAL CAMERA PROFILE!
        
        let gridLineSpacingInMeters : Double = 50 // = 0.5 * cameraHorizontalFOV
        let numOfGridLines : Int = Int(ceil(gridVerticalDist/gridLineSpacingInMeters))
        //var grid : [Line] = [Line]()
        var intersections : [[CLLocationCoordinate2D]] = [[CLLocationCoordinate2D]]()
        for i in 0..<numOfGridLines {
            intersections.append([CLLocationCoordinate2D]())
        }
        
        // TODO: SECTION TO BE EDITED:
        if entryCorner == .TopLeft || entryCorner == .TopRight {
            for i in 1..<numOfGridLines {
                var line : Line = Line(pt1: GMSGeometryOffset(containerRect.topLeftCornerPt, Double(i)*gridLineSpacingInMeters, 180), pt2: GMSGeometryOffset(containerRect.topRightCornerPt, Double(i)*gridLineSpacingInMeters, 180))
                //grid.append(line)
                for anotherLine in polygonLines {
                    if let intersection = line.getIntersectionWith(anotherLine: anotherLine) {
                        if GMSGeometryContainsLocation(intersection, polygonPath, true) {
                            intersections[i].append(intersection)
                        }
                    }
                }
                if entryCorner == .TopLeft {
                    intersections[i].sort{ $0.longitude < $1.longitude }
                } else if entryCorner == .TopRight {
                    intersections[i].sort{ $0.longitude > $1.longitude }
                }
                for intersection in intersections[i] {
                    flightWaypoints.append(intersection)
                }
            }
        } else {
            flightWaypoints.append(closestPointTo(containerRect.bottomLeftCornerPt, among: markerCoordinates))
            flightWaypoints.append(GMSGeometryOffset(flightWaypoints[0], 100, 45))
        }
        
        // TODO: SECTION ENDS
        
        missionWaypoints = flightWaypoints
        return flightWaypoints
    }
    
    // MARK: - Utilities
    
    func closestPointTo(location : CLLocationCoordinate2D, among points : [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        var closestPt : CLLocationCoordinate2D = points[0]
        var closestDist : CLLocationDistance = GMSGeometryDistance(closestPt, location)
        for point in points {
            if GMSGeometryDistance(point, location) < closestDist {
                closestPt = point
                closestDist = GMSGeometryDistance(point, location)
            }
        }
        return closestPt
    }
    
    func clear() {
        markers = [GMSMarker]()
    }
    
}
