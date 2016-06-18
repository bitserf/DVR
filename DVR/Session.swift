import Foundation

public class Session: URLSession {

    // MARK: - Properties

    public var outputDirectory: String
    public let cassetteName: String
    public let backingSession: URLSession
    public var recordingEnabled = true

    private let testBundle: Bundle

    private var recording = false
    private var needsPersistence = false
    private var outstandingTasks = [URLSessionTask]()
    private var completedInteractions = [Interaction]()
    private var completionBlock: ((Void) -> Void)?


    // MARK: - Initializers

    public init(outputDirectory: String = "~/Desktop/DVR/", cassetteName: String, testBundle: Bundle = Bundle.allBundles().filter() { $0.bundlePath.hasSuffix(".xctest") }.first!, backingSession: URLSession = URLSession.shared()) {
        self.outputDirectory = outputDirectory
        self.cassetteName = cassetteName
        self.testBundle = testBundle
        self.backingSession = backingSession
        super.init()
    }


    // MARK: - URLSession
    
    public override func dataTask(with request: URLRequest) -> URLSessionDataTask {
        return addDataTask(request: request)
    }
    
    public override func dataTask(with request: URLRequest, completionHandler: (Data?, URLResponse?, NSError?) -> Void) -> URLSessionDataTask {
        return addDataTask(request: request, completionHandler: completionHandler)
    }
    
    public override func downloadTask(with request: URLRequest) -> URLSessionDownloadTask {
        return addDownloadTask(request: request)
    }
    
    public override func downloadTask(with request: URLRequest, completionHandler: (URL?, URLResponse?, NSError?) -> Void) -> URLSessionDownloadTask {
        return addDownloadTask(request: request, completionHandler: completionHandler)
    }

    public override func invalidateAndCancel() {
        recording = false
        outstandingTasks.removeAll()
        backingSession.invalidateAndCancel()
    }


    // MARK: - Recording

    /// You don’t need to call this method if you're only recoding one request.
    public func beginRecording() {
        if recording {
            return
        }

        recording = true
        needsPersistence = false
        outstandingTasks = []
        completedInteractions = []
        completionBlock = nil
    }

    /// This only needs to be called if you call `beginRecording`. `completion` will be called on the main queue after
    /// the completion block of the last task is called. `completion` is useful for fulfilling an expectation you setup
    /// before calling `beginRecording`.
    public func endRecording(completion: ((Void) -> Void)? = nil) {
        if !recording {
            return
        }

        recording = false
        completionBlock = completion

        if outstandingTasks.count == 0 {
            finishRecording()
        }
    }


    // MARK: - Internal

    var cassette: Cassette? {
        guard let path = testBundle.pathForResource(cassetteName, ofType: "json"),
            data = try? Data(contentsOf: URL(fileURLWithPath: path)),
            raw = try? JSONSerialization.jsonObject(with: data, options: []),
            json = raw as? [String: AnyObject]
        else { return nil }

        return Cassette(dictionary: json)
    }

    func finishTask(task: URLSessionTask, interaction: Interaction, playback: Bool) {
        needsPersistence = needsPersistence || !playback

        if let index = outstandingTasks.index(of: task) {
            outstandingTasks.remove(at: index)
        }

        completedInteractions.append(interaction)

        if !recording && outstandingTasks.count == 0 {
            finishRecording()
        }
    }


    // MARK: - Private

    private func addDataTask(request: URLRequest, completionHandler: ((Data?, URLResponse?, NSError?) -> Void)? = nil) -> URLSessionDataTask {
        let modifiedRequest = backingSession.configuration.httpAdditionalHeaders.map(request.appendingHeaders) ?? request
        let task = SessionDataTask(session: self, request: modifiedRequest, completion: completionHandler)
        addTask(task: task)
        return task
    }

    private func addDownloadTask(request: URLRequest, completionHandler: SessionDownloadTask.Completion? = nil) -> URLSessionDownloadTask {
        let modifiedRequest = backingSession.configuration.httpAdditionalHeaders.map(request.appendingHeaders) ?? request
        let task = SessionDownloadTask(session: self, request: modifiedRequest, completion: completionHandler)
        addTask(task: task)
        return task
    }

    private func addTask(task: URLSessionTask) {
        let shouldRecord = !recording
        if shouldRecord {
            beginRecording()
        }

        outstandingTasks.append(task)

        if shouldRecord {
            endRecording()
        }
    }

    private func persist(interactions: [Interaction]) {
        defer {
            abort()
        }

        // Create directory
        let outputDirectory = (self.outputDirectory as NSString).expandingTildeInPath
        let fileManager = FileManager.default()
        if !fileManager.fileExists(atPath: outputDirectory) {
			do {
                try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true, attributes: nil)
			} catch {
				print("[DVR] Failed to create cassettes directory.")
			}
        }

        let cassette = Cassette(name: cassetteName, interactions: interactions)

        // Persist


        do {
            let outputPath = ((outputDirectory as NSString).appendingPathComponent(cassetteName) as NSString).appendingPathExtension("json")!
            let data = try JSONSerialization.data(withJSONObject: cassette.dictionary, options: [.prettyPrinted])

            // Add trailing new line
            guard var string = String(data: data, encoding: String.Encoding.utf8) else {
                print("[DVR] Failed to persist cassette.")
                return
            }
            string.append("\n")

            if let data = string.data(using: String.Encoding.utf8) {
                (data as NSData).write(toFile: outputPath, atomically: true)
                print("[DVR] Persisted cassette at \(outputPath). Please add this file to your test target")
            }

            print("[DVR] Failed to persist cassette.")
        } catch {
            print("[DVR] Failed to persist cassette.")
        }
    }

    private func finishRecording() {
        if needsPersistence {
            persist(interactions: completedInteractions)
        }

        // Clean up
        completedInteractions = []

        // Call session’s completion block
        completionBlock?()
    }
}
