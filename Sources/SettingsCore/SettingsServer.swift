import AppKit
import Foundation
import Network

public final class SettingsServer: @unchecked Sendable {
    private let listener: NWListener
    private let manager: SettingsManager
    private let queue = DispatchQueue(label: "com.macsettingcontroller.server")
    private let port: UInt16
    private var activeConnections = [ConnectionState]()
    
    public init(port: UInt16, manager: SettingsManager) throws {
        self.port = port
        self.manager = manager
        let nwPort = NWEndpoint.Port(rawValue: port)!
        let parameters = NWParameters.tcp
        
        // Only bind to local loopback interface for security
        parameters.requiredInterfaceType = .loopback
        
        self.listener = try NWListener(using: parameters, on: nwPort)
    }
    
    public func start() {
        let serverPort = self.port
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Server listening on port \(serverPort)")
            case .failed(let error):
                print("Server failed with error: \(error)")
                // Terminate application cleanly on binding conflict or critical bind errors
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "API Server Error"
                    alert.informativeText = "The background API server failed to start on port \(serverPort): \(error.localizedDescription).\n\nIf another instance of this app is running, please quit it first."
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "Quit")
                    alert.runModal()
                    NSApplication.shared.terminate(nil)
                }
            default:
                break
            }
        }
        
        listener.newConnectionHandler = { [weak self] connection in
            guard let self = self else { return }
            self.handleConnection(connection)
        }
        
        listener.start(queue: queue)
    }
    
    public func stop() {
        listener.cancel()
        queue.async {
            for conn in self.activeConnections {
                conn.connection.cancel()
            }
            self.activeConnections.removeAll()
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        let state = ConnectionState(connection: connection, queue: queue)
        activeConnections.append(state)
        
        state.start(onSuccess: { [weak self] requestStr in
            guard let self = self else { return }
            self.routeRequest(connection, requestStr: requestStr)
        }, onFailure: { [weak self] statusCode, json in
            guard let self = self else { return }
            self.sendResponse(connection, statusCode: statusCode, json: json)
        }, onClose: { [weak self, weak state] in
            guard let self = self, let state = state else { return }
            self.activeConnections.removeAll(where: { $0 === state })
        })
    }
    
    private func routeRequest(_ connection: NWConnection, requestStr: String) {
        let lines = requestStr.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(connection, statusCode: 400, json: ["error": "Malformed request"])
            return
        }
        
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection, statusCode: 400, json: ["error": "Malformed request line"])
            return
        }
        
        let method = parts[0]
        let path = parts[1]
        
        if method == "GET" && path == "/health" {
            sendResponse(connection, statusCode: 200, json: ["status": "ok"])
            return
        }
        
        if method == "GET" && path == "/browsers" {
            let browsers = manager.getInstalledBrowsers()
            let defaultBrowser = manager.getDefaultBrowser()
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            struct BrowsersResponse: Codable {
                let browsers: [BrowserInfo]
                let defaultBrowser: BrowserInfo?
            }
            
            let responseObj = BrowsersResponse(browsers: browsers, defaultBrowser: defaultBrowser)
            if let responseData = try? encoder.encode(responseObj) {
                sendRawResponse(connection, statusCode: 200, contentType: "application/json", data: responseData)
            } else {
                sendResponse(connection, statusCode: 500, json: ["error": "Encoding error"])
            }
            return
        }
        
        if method == "POST" && path == "/set_default" {
            guard let bodyIndex = requestStr.range(of: "\r\n\r\n")?.upperBound else {
                sendResponse(connection, statusCode: 400, json: ["error": "Missing HTTP body separator"])
                return
            }
            
            let body = String(requestStr[bodyIndex...])
            guard let bodyData = body.data(using: .utf8) else {
                sendResponse(connection, statusCode: 400, json: ["error": "Invalid body encoding"])
                return
            }
            
            struct SetDefaultRequest: Codable {
                let bundleIdentifier: String
            }
            
            guard let requestObj = try? JSONDecoder().decode(SetDefaultRequest.self, from: bodyData) else {
                sendResponse(connection, statusCode: 400, json: ["error": "Invalid JSON payload or missing bundleIdentifier"])
                return
            }
            
            manager.setDefaultBrowser(bundleIdentifier: requestObj.bundleIdentifier) { [weak self] error in
                guard let self = self else { return }
                self.queue.async {
                    if let error = error {
                        self.sendResponse(connection, statusCode: 500, json: ["error": error.localizedDescription])
                    } else {
                        self.sendResponse(connection, statusCode: 200, json: ["status": "success"])
                    }
                }
            }
            return
        }
        
        sendResponse(connection, statusCode: 404, json: ["error": "Endpoint not found"])
    }
    
    private func sendResponse(_ connection: NWConnection, statusCode: Int, json: [String: String]) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(json) else {
            sendRawResponse(connection, statusCode: 500, contentType: "text/plain", data: "Internal Server Error".data(using: .utf8)!)
            return
        }
        sendRawResponse(connection, statusCode: statusCode, contentType: "application/json", data: data)
    }
    
    private func sendRawResponse(_ connection: NWConnection, statusCode: Int, contentType: String, data: Data) {
        var statusStr = "Unknown"
        switch statusCode {
        case 200: statusStr = "OK"
        case 400: statusStr = "Bad Request"
        case 404: statusStr = "Not Found"
        case 500: statusStr = "Internal Server Error"
        default: break
        }
        
        let headers = [
            "HTTP/1.1 \(statusCode) \(statusStr)",
            "Content-Type: \(contentType)",
            "Content-Length: \(data.count)",
            "Connection: close",
            "Access-Control-Allow-Origin: *",
            "",
            ""
        ].joined(separator: "\r\n")
        
        guard let headerData = headers.data(using: .utf8) else {
            connection.cancel()
            return
        }
        
        var responseData = Data()
        responseData.append(headerData)
        responseData.append(data)
        
        connection.send(content: responseData, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed({ error in
            if let error = error {
                print("Send error: \(error)")
            }
            connection.cancel()
        }))
    }
}

private final class ConnectionState: @unchecked Sendable {
    let connection: NWConnection
    let queue: DispatchQueue
    var accumulatedData = Data()
    
    init(connection: NWConnection, queue: DispatchQueue) {
        self.connection = connection
        self.queue = queue
    }
    
    func start(
        onSuccess: @escaping @Sendable (String) -> Void,
        onFailure: @escaping @Sendable (Int, [String: String]) -> Void,
        onClose: @escaping @Sendable () -> Void
    ) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .cancelled, .failed:
                onClose()
            default:
                break
            }
        }
        connection.start(queue: queue)
        receiveNext(onSuccess: onSuccess, onFailure: onFailure)
    }
    
    private func receiveNext(onSuccess: @escaping @Sendable (String) -> Void, onFailure: @escaping @Sendable (Int, [String: String]) -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if error != nil {
                self.connection.cancel()
                return
            }
            
            if let data = data, !data.isEmpty {
                self.accumulatedData.append(data)
                
                if self.isRequestComplete(self.accumulatedData) {
                    if let requestStr = String(data: self.accumulatedData, encoding: .utf8) {
                        onSuccess(requestStr)
                    } else {
                        onFailure(400, ["error": "Invalid request encoding"])
                    }
                } else if !isComplete {
                    self.receiveNext(onSuccess: onSuccess, onFailure: onFailure)
                } else {
                    self.connection.cancel()
                }
            } else if isComplete {
                self.connection.cancel()
            } else {
                self.receiveNext(onSuccess: onSuccess, onFailure: onFailure)
            }
        }
    }
    
    private func isRequestComplete(_ data: Data) -> Bool {
        let separator = Data([13, 10, 13, 10]) // "\r\n\r\n"
        guard let separatorRange = data.range(of: separator) else {
            let altSeparator = Data([10, 10]) // "\n\n"
            if data.range(of: altSeparator) != nil {
                return true
            }
            return false
        }
        
        // Extract headers
        let headerData = data.subdata(in: 0..<separatorRange.lowerBound)
        guard let headerStr = String(data: headerData, encoding: .utf8) else {
            return true
        }
        
        let lines = headerStr.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return true }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 1 else { return true }
        
        let method = parts[0].uppercased()
        if method != "POST" {
            return true
        }
        
        // Parse Content-Length for POST request
        var contentLength = 0
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if key == "content-length" {
                    contentLength = Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                }
            }
        }
        
        let bodyStartIndex = separatorRange.upperBound
        let receivedBodyLength = data.count - bodyStartIndex
        return receivedBodyLength >= contentLength
    }
}
