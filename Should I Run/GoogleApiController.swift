//
//  GoogleApiController.swift
//  Should I Run
//
//  Created by Neil Lobo on 7/17/14.
//  Copyright (c) 2014 Should I Run. All rights reserved.
//

import UIKit



protocol GoogleAPIControllerProtocol {
    func didReceiveGoogleResults(results: Array<String>!, error:String?)
    func didReceiveGoogleResults(results: [(distanceToStation: String, muniOriginStationName: String, lineCode: String, lineName: String, eolStationName: String)], muni: Bool)
}


class GoogleApiController: NSObject{
    
    var delegate : GoogleAPIControllerProtocol?
    
    var doNotRun = true
    
    func fetchGoogleData(locName: String, latDest:Float, lngDest:Float, latStart:Float, lngStart:Float) {
        var cache = NSMutableArray(contentsOfFile: NSBundle.mainBundle().pathForResource("Cache", ofType: "plist"))
//        println("Cache is \(cache[""])")
        var time = Int(NSDate().timeIntervalSince1970)

        for item in cache {
            var cachedLocaton = item["location"] as String
            var cachedPosition = item["position"] as Float
            var cachedTime = item["time"] as Int
            if ( cachedLocaton == locName && cachedPosition == latStart && (time - cachedTime < 600) ) {
                println("Cached Results found")
                doNotRun = false
                var cachedResults = item["results"] as NSDictionary
                 self.convertGoogleToBart(cachedResults)
            }
        }
       

        var url = NSURL(string: "https://maps.googleapis.com/maps/api/directions/json?origin=\(latStart),\(lngStart)&destination=\(latDest),\(lngDest)&key=AIzaSyB9JV82Cy-GFPTAbYy3HgfZOGT75KVp-dg&departure_time=\(time)&mode=transit&alternatives=true")
        
        var request = NSURLRequest(URL: url)
        if doNotRun {

           NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {
            (response, data, error) in

            
            if error {
                println("Error!!",error)
            } else {

            let jsonDict = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers, error: nil) as NSDictionary
            var cache = NSMutableArray(contentsOfFile: NSBundle.mainBundle().pathForResource("Cache", ofType: "plist"))
            cache.insertObject(["time" : time, "location" : locName, "position" : latStart, "results" : jsonDict], atIndex: cache.count)

            let done = cache.writeToFile(NSBundle.mainBundle().pathForResource("Cache", ofType: "plist"), atomically: false)

        }
        
    }
   
    func parseGoogleTransitData(goog: NSDictionary) {
        var results :[String] = []
        
        var walkingStepIndex = 0
        
        
        var allRoutes = goog.objectForKey("routes") as [NSDictionary]
        var inter2 : NSArray = allRoutes[0].objectForKey("legs") as NSArray
        var steps : NSArray = inter2[0].objectForKey("steps") as NSArray
        
//Bart helper functions
        func findBart(stepsArray: NSArray) -> NSDictionary? {
            var result:NSDictionary?
            
            for var i = 1; i < steps.count; ++i {

                if let transit_details = steps[i].objectForKey("transit_details") as? NSDictionary {

                    if let line:NSDictionary = transit_details.objectForKey("line") as? NSDictionary {

                        if let agencies = line.objectForKey("agencies") as? NSArray {

                            if let name = agencies[0].objectForKey("name") as? String {

                                if name == "Bay Area Rapid Transit" {
                                    result = (steps[i] as NSDictionary)
                                    walkingStepIndex = i - 1
                                    return result
                                }
                            }
                        }
                    }
                }
            }
            return result
        }
        
        func getDistanceFromWalkingStep(walkingStep: NSDictionary) -> String {
            var result:String = ""
            
            var distanceDictinary = walkingStep.objectForKey("distance") as NSDictionary
            
            var distance = String(distanceDictinary.objectForKey("value").intValue) //stored as an int so we need to conver t to string
            
            result = distance
            
            return result
        }
        
        func getOriginStationFromWalkingStep(step: NSDictionary) -> Array<String> {
            
            var result:[String] = []
            var instructions:NSString = step.objectForKey("html_instructions") as NSString
            
            //trim off first 7 characters to get station name

            var originStationName = instructions.substringFromIndex(7)
                .stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            
            //get code for station
            var originStationCode = bartLookup[originStationName]!.uppercaseString
            
            
            result.append(originStationCode)
            
            return result
        }

        func getEOLStationFromBartStep(step: NSDictionary) -> Array<String> {
            
            var result:[String] = []
            var instructions:NSString = step.objectForKey("html_instructions") as NSString
            
            //trim off first 7 characters to get station name
            
            var eolStationName = instructions.substringFromIndex(19).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            
            //get code for station

            var eolStationCode = bartLookup[eolStationName]?.uppercaseString
            result.append(eolStationCode!)
            return result
        }
        
        func getAllEOLStations(routes: NSArray) -> [String] {
            var results:[String]  = []
            
            //iterate through each route and get the EOL station
            for var i = 1; i < routes.count; ++i {
                var legs : NSArray = routes[i].objectForKey("legs") as NSArray
                var steps : NSArray = legs[0].objectForKey("steps") as NSArray
                if let bartStep:NSDictionary = findBart(steps)? {
                    results += getEOLStationFromBartStep(bartStep)
                }
            }
            return results
        }
        
// muni helper functions
        
        func getMuniOriginStationFromWalkingStep(step: NSDictionary) -> String {
            
            var instructions:NSString = step.objectForKey("html_instructions") as NSString
            
            //trim off first 7 characters to get station name
            var originStationName = instructions.substringFromIndex(7)
                .stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            
            return originStationName
            
        }
        func getLineCodeFromMuniStep(step:NSDictionary) -> String {
            if let transit_details = step.objectForKey("transit_details") as? NSDictionary {
                if let line:NSDictionary = transit_details.objectForKey("line") as? NSDictionary {
                    var shortName = line.objectForKey("short_name") as NSString
                    return shortName
                }
            }
            return "error"
        }
        func getLineNameFromMuniStep(step:NSDictionary) -> String {
            if let transit_details = step.objectForKey("transit_details") as? NSDictionary {
                if let line:NSDictionary = transit_details.objectForKey("line") as? NSDictionary {
                    var lineName = line.objectForKey("name") as NSString
                    return lineName
                }
            }
            return "error"
        }

        func getEolStationNameFromMuniStep(step:NSDictionary) -> String {

            var instructions:NSString = step.objectForKey("html_instructions") as NSString
            
            // google will return two possible results here:
            // "Bus towards the Sunset District"
            // "Light rail towards Balboa Park Station via Downtown"
            // so we need to check the first character, which will determine the length of what needs to be sliced off
            // NSString.characterAtIndex(0) -> returns a character code
            // B == 66
            // L == 76
            var eolStationName = "error" // if it's not a bus or light rail, send back an error
            
            if instructions.characterAtIndex(0) == 66 {
                eolStationName = instructions.substringFromIndex(12).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                
            } else if instructions.characterAtIndex(0) == 76 {
                eolStationName = instructions.substringFromIndex(18).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                
            }
            
            return eolStationName
        }
        
        func getMuniData(allRoutes: [NSDictionary]) -> [(distanceToStation: String, muniOriginStationName: String, lineCode: String, lineName: String, eolStationName: String)]? {
            var result:[(distanceToStation: String, muniOriginStationName: String, lineCode: String, lineName: String, eolStationName: String)] = []
            for route in allRoutes  {
                if let legs = route.objectForKey("legs") as? [NSDictionary] {
                    //for whatever reason legs is always an array with only one element
                    if let steps = legs[0].objectForKey("steps") as? [NSDictionary] {
                        for var i = 1; i < steps.count; ++i {
                            
                            if let transit_details = steps[i].objectForKey("transit_details") as? NSDictionary {
                                
                                if let line:NSDictionary = transit_details.objectForKey("line") as? NSDictionary {
                                    
                                    if let agencies = line.objectForKey("agencies") as? NSArray {
                                        
                                        if let name = agencies[0].objectForKey("name") as? String {
                                            
                                            if name == "San Francisco Municipal Transportation Agency" {
                                                
                                                //For now, limiting to light rail by checking the vehicle type
                                                //comment out this block to remove the limitation
                                                if let vehicle = line.objectForKey("vehicle") as? NSDictionary {
                                                    
                                                    if let type = vehicle.objectForKey("type") as? String {
                                                        
                                                        if type == "TRAM" {
                                                            //but keep this part
                                                            
                                                            // now that we have the step, get the data
                                                            
                                                            var thisResult: (distanceToStation: String, muniOriginStationName: String, lineCode: String, lineName: String, eolStationName: String)
                                                            var thisStep = steps[i] as NSDictionary
                                                            var walkingStep = steps[i - 1] as NSDictionary
                                                            
                                                            thisResult.distanceToStation =  getDistanceFromWalkingStep(walkingStep)
                                                            thisResult.muniOriginStationName =  getMuniOriginStationFromWalkingStep(walkingStep)
                                                            thisResult.lineCode = getLineCodeFromMuniStep(thisStep)
                                                            thisResult.lineName = getLineNameFromMuniStep(thisStep)
                                                            thisResult.eolStationName = getEolStationNameFromMuniStep(thisStep)
                                                            
                                                            result.insert(thisResult, atIndex: result.count)
                                                            //return to commenting
                                                        }
                                                    }
                                                }
                                                //end commenting
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if result.count == 0 {
                return nil
            } else {
                return result
            }
        }


        
        if let bartStep:NSDictionary = findBart(steps)? {
            results += getDistanceFromWalkingStep(steps[walkingStepIndex] as NSDictionary)
            results += getOriginStationFromWalkingStep(steps[walkingStepIndex] as NSDictionary)
            results += getAllEOLStations(allRoutes)
            
            self.delegate?.didReceiveGoogleResults(results, error: nil)

        } else if let muniData = getMuniData(allRoutes)? {

            //results: [distance to station, station name, line code, line name, EOL station]
            
            self.delegate?.didReceiveGoogleResults(muniData, muni: true)
            
        } else {
            //error, no bart
            //TODO: trigger segue back to main screen with error
            println("No bart or muni")
            self.delegate?.didReceiveGoogleResults(nil, error: "No bart or muni")

        }
    }
}
