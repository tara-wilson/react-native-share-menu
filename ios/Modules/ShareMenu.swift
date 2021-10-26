import AVFoundation
//import AVFAudio
//import SoundAnalysis
//import CoreML

@objc(ShareMenu)
class ShareMenu: RCTEventEmitter {

    private(set) static var _shared: ShareMenu?
    @objc public static var shared: ShareMenu
    {
        get {
            return ShareMenu._shared!
        }
    }

    var sharedData: [String:String]?

    static var initialShare: (UIApplication, URL, [UIApplication.OpenURLOptionsKey : Any])?

    var hasListeners = false

    var _targetUrlScheme: String?
    var targetUrlScheme: String
    {
        get {
            return _targetUrlScheme!
        }
    }

    public override init() {
        super.init()
        ShareMenu._shared = self

        if let (app, url, options) = ShareMenu.initialShare {
            share(application: app, openUrl: url, options: options)
        }
    }

    override static public func requiresMainQueueSetup() -> Bool {
        return false
    }

    open override func supportedEvents() -> [String]! {
        return [NEW_SHARE_EVENT]
    }

    open override func startObserving() {
        hasListeners = true
    }

    open override func stopObserving() {
        hasListeners = false
    }

    public static func messageShare(
        application app: UIApplication,
        openUrl url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any]
    ) {
        guard (ShareMenu._shared != nil) else {
            initialShare = (app, url, options)
            return
        }
        
        ShareMenu.shared.share(application: app, openUrl: url, options: options)
    }
    
    func share(
        application app: UIApplication,
        openUrl url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any]) {
        if _targetUrlScheme == nil {
            guard let bundleUrlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [NSDictionary] else {
                print("Error: \(NO_URL_TYPES_ERROR_MESSAGE)")
                return
            }
            guard let bundleUrlSchemes = bundleUrlTypes.first?.value(forKey: "CFBundleURLSchemes") as? [String] else {
                print("Error: \(NO_URL_SCHEMES_ERROR_MESSAGE)")
                return
            }
            guard let expectedUrlScheme = bundleUrlSchemes.first else {
                print("Error \(NO_URL_SCHEMES_ERROR_MESSAGE)")
                return
            }

            _targetUrlScheme = expectedUrlScheme
        }

        guard let scheme = url.scheme else { return }
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        guard let userDefaults = UserDefaults(suiteName: "group.\(bundleId)") else {
            print("Error: \(NO_APP_GROUP_ERROR)")
            return
        }
        
        if (scheme == "file") {
            saveFileMetadata(url: url)
        }


        let extraData = userDefaults.object(forKey: USER_DEFAULTS_EXTRA_DATA_KEY) as? [String:Any]

        if let data = userDefaults.object(forKey: USER_DEFAULTS_KEY) as? [String:String] {
            sharedData = data
            dispatchEvent(with: data, and: extraData)
            userDefaults.removeObject(forKey: USER_DEFAULTS_KEY)
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    func saveFileMetadata(url: URL) {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        guard let userDefaults = UserDefaults(suiteName: "group.\(bundleId)") else {
            print("Error: \(NO_APP_GROUP_ERROR)")
            return
        }
        
        guard let groupFileManagerContainer = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.\(bundleId)")
        else {
          return
        }
        
        do {
            let mimeType = url.extractMimeType()
            if (mimeType.contains("audio")) {
                let asset = AVAsset.init(url: url)
                let duration = asset.duration.seconds
                userDefaults.setValue(duration, forKey: "last_url_share_duration");
                
                let metadata = asset.metadata
                var metadataDict: [String: Any] = [:]
                metadata.forEach({ item in
                    if let id = item.identifier {
                        if let strVal = item.stringValue {
                            metadataDict[id.rawValue] = strVal
                        }
                        else if let nVal = item.numberValue {
                            metadataDict[id.rawValue] = nVal
                        } else if id == AVMetadataIdentifier("id3/APIC"), let dataval = item.dataValue {
                            var image: UIImage = UIImage(data: dataval)!
                            if let data = image.pngData() {
                                let filename = groupFileManagerContainer
                                  .appendingPathComponent("temp.png")
                               
//                                let filename = getDocumentsDirectory().appendingPathComponent("copy.png")
                                    try? data.write(to: filename)
                           
                                userDefaults.setValue(filename.absoluteURL.absoluteString, forKey: "last_url_share_image");
                            }
                          
                        } else {
                            print("tara here could not get", item.identifier)

                        }
                    }
                })
             
              
                let jsonData = try JSONSerialization.data(withJSONObject: metadataDict, options: .prettyPrinted)
                let jsonString = String(data: jsonData, encoding: String.Encoding.utf8)
                userDefaults.setValue(jsonString, forKey: "last_url_share_metadata");
                userDefaults.synchronize();
            }
        } catch {
            print(error)
        }
       


        
//        if #available(iOS 13.0, *) {
//
//
//            /// An observer that receives results from a classify sound request.
//            class ResultsObserver: NSObject, SNResultsObserving {
//                /// Notifies the observer when a request generates a prediction.
//                func request(_ request: SNRequest, didProduce result: SNResult) {
//                    // Downcast the result to a classification result.
//                    guard let result = result as? SNClassificationResult else  { return }
//
//                    // Get the prediction with the highest confidence.
//                    guard let classification = result.classifications.first else { return }
//
//                    // Get the starting time.
//                    let timeInSeconds = result.timeRange.start.seconds
//
//                    // Convert the time to a human-readable string.
//                    let formattedTime = String(format: "%.2f", timeInSeconds)
//                    print("Analysis result for audio at time: \(formattedTime)")
//
//                    // Convert the confidence to a percentage string.
//                    let percent = classification.confidence * 100.0
//                    let percentString = String(format: "%.2f%%", percent)
//
//                    // Print the classification's name (label) with its confidence.
//                    print("\(classification.identifier): \(percentString) confidence.\n")
//                }
//
//
//                /// Notifies the observer when a request generates an error.
//                func request(_ request: SNRequest, didFailWithError error: Error) {
//                    print("The the analysis failed: \(error.localizedDescription)")
//                }
//
//                /// Notifies the observer when a request is complete.
//                func requestDidComplete(_ request: SNRequest) {
//                    print("The request completed successfully!")
//                }
//            }
//
//            do {
//                let audioFileAnalyzer = try SNAudioFileAnalyzer(url: url)
//                let resultsObserver = ResultsObserver()
//                let version1 = SNClassifierIdentifier.version1
//                let request = try SNClassifySoundRequest(mlModel: version1)
//                try audioFileAnalyzer.add(request, withObserver: resultsObserver)
//                audioFileAnalyzer.analyze()
//
//            } catch {
//            print(error)
//            }
//
//        } else {
//            // Fallback on earlier versions
//        }
//
      
      
    }
    
    func moveFileToDisk(from srcUrl: URL, to destUrl: URL) -> Bool {
      do {
        if FileManager.default.fileExists(atPath: destUrl.path) {
          try FileManager.default.removeItem(at: destUrl)
        }
        try FileManager.default.copyItem(at: srcUrl, to: destUrl)
      } catch (let error) {
        print("Could not save file from \(srcUrl) to \(destUrl): \(error)")
        return false
      }
      
      return true
    }

    @objc(getSharedText:)
    func getSharedText(callback: RCTResponseSenderBlock) {
        guard var data: [String:Any] = sharedData else {
            callback([])
            return
        }

        if let bundleId = Bundle.main.bundleIdentifier, let userDefaults = UserDefaults(suiteName: "group.\(bundleId)") {
            data[EXTRA_DATA_KEY] = userDefaults.object(forKey: USER_DEFAULTS_EXTRA_DATA_KEY) as? [String:Any]
        } else {
            print("Error: \(NO_APP_GROUP_ERROR)")
        }

        callback([data as Any])
        sharedData = nil
    }
    
    func dispatchEvent(with data: [String:String], and extraData: [String:Any]?) {
        guard hasListeners else { return }

        var finalData = data as [String:Any]
        if (extraData != nil) {
            finalData[EXTRA_DATA_KEY] = extraData
        }
        
        sendEvent(withName: NEW_SHARE_EVENT, body: finalData)
    }
}
