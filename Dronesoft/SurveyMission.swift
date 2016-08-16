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
    func surveyMissionDidAddNewMarker(markers: [GMSMarker])
    func surveyMissionDidUpdatePolygon(polygon: GMSPolygon)
    func surveyMissionDidUpdateFlightPath(flightPath: GMSPolyline)
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
        if determinant != 0 {
            let x = (c*e - b*f)/determinant;
            let y = (a*f - c*d)/determinant;
            return CLLocationCoordinate2D(latitude: y, longitude: x)
        } else {
            return nil;
        }
    }
    
    // MARK: DEBUG ONLY FUNC
    func displayOnMap(mapView: GMSMapView) {
        let linePath = GMSMutablePath()
        linePath.addCoordinate(pt1)
        linePath.addCoordinate(pt2)
        GMSPolyline(path: linePath).map = mapView
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
    var path : GMSMutablePath {
        let rectPath = GMSMutablePath()
        rectPath.addCoordinate(topLeftCornerPt)//.ceilCoordinateAfterDecimals(5))
        rectPath.addCoordinate(bottomLeftCornerPt)//.ceilCoordinateAfterDecimals(5))
        rectPath.addCoordinate(bottomRightCornerPt)//.ceilCoordinateAfterDecimals(5))
        rectPath.addCoordinate(topRightCornerPt)//.ceilCoordinateAfterDecimals(5))
        return rectPath
    }
    
    // MARK: DEBUG ONLY FUNC
    func displayOnMap(mapView: GMSMapView) {
        GMSPolygon(path: path).map = mapView
    }
}

class SurveyMission: NSObject {
    var markers : [GMSMarker]! {
        didSet {
            if markers.count == 0 {
                polygonCenter = CLLocationCoordinate2D()
            }
            
            var cumulativeLat : Double = 0.0, cumulativeLong : Double = 0.0
            for marker in markers {
                cumulativeLat += marker.position.latitude
                cumulativeLong += marker.position.longitude
            }
            polygonCenter = CLLocationCoordinate2D(latitude: cumulativeLat/Double(markers.count), longitude: cumulativeLong/Double(markers.count))
        }
    }
    
    var polygon : GMSPolygon!
    
    private(set) var polygonCenter : CLLocationCoordinate2D!
    
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
    
    var delegate : SurveyMissionDelegate? = nil
    
    private(set) var missionWaypoints : [CLLocationCoordinate2D]! {
        didSet {
            let path : GMSMutablePath = GMSMutablePath()
            for coordinate in missionWaypoints {
                path.addCoordinate(coordinate)
            }
            flightPath.path = path
            delegate?.surveyMissionDidUpdateFlightPath(flightPath)
        }
    }
    
    private(set) var flightPath : GMSPolyline!
    
    init(delegate : SurveyMissionDelegate) {
        markers = [GMSMarker]()
        
        polygon = GMSPolygon()
        polygon.fillColor = UIColor(red: 0, green: 0, blue: 1.0, alpha: 0.25);
        polygon.strokeColor = UIColor.whiteColor()
        polygon.strokeWidth = 2
        polygon.tappable = true
        
        flightPath = GMSPolyline()
        flightPath.strokeColor = UIColor.redColor()
        
        //IMPORTANT: missionWaypoints should always be initialized after flightPath
        missionWaypoints = [CLLocationCoordinate2D]()
        
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
            delegate.surveyMissionDidAddNewMarker(markers)
        }
    }
    
    func updatePolygon() {
        polygon.path = polygonPath
        
        if let delegate = delegate {
            delegate.surveyMissionDidUpdatePolygon(polygon)
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
        //let gridLineLength : Double = containerRect.horizontalDistance
        let gridVerticalDist : Double = containerRect.verticalDistance
        
        // TODO: GET ACTUAL CAMERA PROFILE HERE!
        //       Then use GridLineLength to calculate picture pts.
        
        let gridLineSpacingInMeters : Double = 50 // = 0.5 * cameraHorizontalFOV
        let numOfGridLines : Int = Int(ceil(gridVerticalDist/gridLineSpacingInMeters))
        //var grid : [Line] = [Line]()
        var intersections : [[CLLocationCoordinate2D]] = [[CLLocationCoordinate2D]]()
        for _ in 0..<numOfGridLines {
            intersections.append([CLLocationCoordinate2D]())
        }
        
        /* TODO: SECTION TO BE COMPLETED: DEBUG & IMPROVE FIRST
            THEN IMPLEMENT .BottomLeft and .BottomRight entries
         */
        if entryCorner == .TopLeft || entryCorner == .TopRight {
            for i in 1..<numOfGridLines {
                let line : Line = Line(pt1: GMSGeometryOffset(containerRect.topLeftCornerPt, Double(i)*gridLineSpacingInMeters, 180), pt2: GMSGeometryOffset(containerRect.topRightCornerPt, Double(i)*gridLineSpacingInMeters, 180))
                //grid.append(line)
                line.displayOnMap(polygon.map!)
                for anotherLine in polygonLines {
                    if let intersection = line.getIntersectionWith(anotherLine: anotherLine) {
                        if GMSGeometryContainsLocation(intersection, getSlightlyEnlargedPolygonPath(), true) {
                            intersections[i].append(intersection)
                        }
                    }
                }
                if (entryCorner == .TopLeft && i % 2 == 1) ||
                    (entryCorner == .TopRight && i % 2 == 0) {
                    intersections[i].sortInPlace{ $0.longitude < $1.longitude }
                } else if (entryCorner == .TopRight && i % 2 == 1) ||
                    (entryCorner == .TopLeft && i % 2 == 0) {
                    intersections[i].sortInPlace{ $0.longitude > $1.longitude }
                }
                for intersection in intersections[i] {
                    flightWaypoints.append(intersection)
                }
            }
        } else {
            flightWaypoints.append(closestPointTo(containerRect.bottomLeftCornerPt, among: markerCoordinates))
            flightWaypoints.append(GMSGeometryOffset(flightWaypoints[0], 1000, 45))
        }
        
        //If the region is so small that no intersections were found, take a picture in the center of the polygon
        if flightWaypoints.isEmpty {
            flightWaypoints.append(polygonCenter)
        }
        
        // Debug
        containerRect.displayOnMap(polygon.map!)
        
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
    
    func getSlightlyEnlargedPolygonPath() -> GMSMutablePath {
        let path = GMSMutablePath()
        if markers.count == 0 {
            return path
        }
        for marker in markers {
            path.addCoordinate(GMSGeometryOffset(marker.position, 1, GMSGeometryHeading(polygonCenter, marker.position)))
        }
        return path
    }
    
    func clear() {
        markers = [GMSMarker]()
    }
    
}

extension CLLocationCoordinate2D {
    func ceilCoordinateAfterDecimals(decimals: Int) -> CLLocationCoordinate2D {
        print("\(self), \(self.latitude.ceilAfterDecimals(5))")
        return CLLocationCoordinate2D(latitude: latitude.ceilAfterDecimals(decimals), longitude: longitude.ceilAfterDecimals(decimals))
    }
}

extension CLLocationDegrees{
    func ceilAfterDecimals(decimals: Int) -> CLLocationDegrees {
        return ceil((pow(10.0, Double(decimals))*self))/pow(10.0, Double(decimals))
    }
}
