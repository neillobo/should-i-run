//
//  BartApiController.swift
//  Should I Run
//
//  Created by LM on 7/17/14.
//  Copyright (c) 2014 Should I Run. All rights reserved.
//

import UIKit

// Create BART API protocol that needs to be adhered to
protocol BartApiControllerDelegate {
    // Actual implementation of methods needs to be written inside the class using this protocol
    func didReceiveBartResults(results: [(String, Int)])
    func handleError(errorMessage: String)
}

class BartApiController: NSObject, NSURLConnectionDelegate, NSURLConnectionDataDelegate {

    // Create delegate
    // Can be any class, as long as it adheres to BartApiControllerProtocol (by defining didReceiveBartResults in this case)
    var delegate: BartApiControllerDelegate?
    
    // Create a reference to our BART connection so we can cancel it later
    var currentBartConnection: NSURLConnection?
    var currentBartData: NSMutableData = NSMutableData()

// MARK: BART API Connection Methods
    
    // Cancel the connection the BART connection.
    func cancelConnection() {
        println("cancelling BART request")
        self.currentBartConnection?.cancel()
    }

    // If BART connection fails, handle error here
    func connection(connection: NSURLConnection!, didFailWithError error: NSError!) {
        self.delegate?.handleError("BART connection failed")
    }
    
    // On connection success, handle data we get from BART
    func connection(connection: NSURLConnection!, didReceiveData data: NSData!) {
        self.currentBartData.appendData(data)
    }
    
    // On connection success, handle data we get from the BART API
    func connectionDidFinishLoading(connection: NSURLConnection!) {
        self.handleConnectionCallbackWithData(currentBartData, andError: nil)
    }
    
// MARK: Search and Handle BART Data

    func searchBartFor(searchAbbr: String) {
        // Fetch information for the BART api and convert the returned XML into a dictionary
        let url = NSURL(string: "http://api.bart.gov/api/etd.aspx?cmd=etd&orig=" + searchAbbr + "&key=ZELI-U2UY-IBKQ-DT35")
        
        var request = NSURLRequest(URL: url)
        
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        // Initiate the request and save the reference so we can do operations on it later
        self.currentBartConnection = NSURLConnection.connectionWithRequest(request, delegate: self)
    }
    
    func handleConnectionCallbackWithData(data:NSData?, andError error:NSError?){
        if let err = error? {
            self.delegate?.handleError("BART connection failed")
            return
        }
        
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        
        let html = NSString(data: data, encoding: NSUTF8StringEncoding)
        let parsed: NSDictionary = XMLReader.dictionaryForXMLString(html, error: nil)
        
        // Trim off unneeded data inside the dictionary
        let stations: NSDictionary = parsed.objectForKey("root").objectForKey("station") as NSDictionary
        
        // Create an array of tuples to store our destination stations (termini) and their estimated arrival time to our closest BART  station
        var allResults: [(String, Int)] = []
        
        // Iterate over our stations
        for aStation in stations {
            
            if (aStation.key as String == "etd") {
                
                
                // Check if stations are in an Array, or if there is only one station, a Dictionary
                // If Dictionary, insert into an Array to iterate over
                var etdList:[NSDictionary] = []
                
                if let ival:[NSDictionary] = aStation.value as? [NSDictionary] {
                    etdList += ival
                    
                } else if let ival:NSDictionary = aStation.value as? NSDictionary {
                    etdList.append(ival)
                    
                }
                
                
                
                
                for stationItem in etdList as [NSDictionary] {
                    var abbr = stationItem["abbreviation"] as NSDictionary
                    
                    // same issue for departures
                    // Check if departures are in an Array, or if there is only one station, a Dictionary
                    // If Dictionary, insert into an Array to iterate over
                    
                    var estimateList:[NSDictionary] = []
                    
                    if let estimate:[NSDictionary] = stationItem["estimate"] as? [NSDictionary]{
                        estimateList += estimate
                        
                    } else if let estimate:NSDictionary = stationItem["estimate"] as? NSDictionary {
                        estimateList.append(estimate)
                        
                    }
                    
                    for estimateItem in estimateList as [AnyObject] {
                        var estimateMin = estimateItem["minutes"] as NSDictionary
                        
                        // Create the terminus and estimated arrival tuple and push into our results
                        var myTuple: (String, Int) = (abbr["text"] as String, estimateMin["text"].integerValue)
                        allResults += myTuple
                    }
                }
            }
        }
        
        // Sort the tuple array of termini and estimated arrival in ascending order
        allResults.sort{$0.1 < $1.1}
        
        self.delegate?.didReceiveBartResults(allResults)

        
    }
}
    