import Foundation
import PDFKit
import Quartz
import Vision

class OllamaService: ObservableObject {
    private let baseURL = "http://localhost:11434"

    @Published var availableModels: [String] = []
    @Published var isConnected = false

    private var session: URLSession!
    private var checkSession: URLSession!
    private var isCheckingConnection = false

    init() {
        // Create a custom session configuration for long-running chat requests
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes for long responses
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)

        // Create a separate session for quick connection checks
        let checkConfig = URLSessionConfiguration.default
        checkConfig.timeoutIntervalForRequest = 2 // 2 seconds timeout for connection checks
        checkConfig.timeoutIntervalForResource = 2
        self.checkSession = URLSession(configuration: checkConfig)

        // Check connection asynchronously without blocking
        Task { @MainActor in
            await checkConnectionAsync()
        }
    }

    func checkConnection() {
        Task { @MainActor in
            await checkConnectionAsync()
        }
    }

    private func checkConnectionAsync() async {
        // Prevent multiple simultaneous connection checks
        guard !isCheckingConnection else { return }
        isCheckingConnection = true

        defer { isCheckingConnection = false }

        guard let url = URL(string: "\(baseURL)/api/tags") else { return }

        do {
            let (_, response) = try await checkSession.data(from: url)

            await MainActor.run {
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    self.isConnected = true
                    // Only fetch models if connection is successful
                    Task {
                        await self.fetchModelsAsync()
                    }
                } else {
                    self.isConnected = false
                }
            }
        } catch {
            await MainActor.run {
                self.isConnected = false
            }
        }
    }

    func fetchModels() {
        Task {
            await fetchModelsAsync()
        }
    }

    private func fetchModelsAsync() async {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return }

        do {
            let (data, _) = try await checkSession.data(from: url)
            let response = try JSONDecoder().decode(ModelsResponse.self, from: data)

            await MainActor.run {
                self.availableModels = response.models.map { $0.name }
                self.isConnected = true
            }
        } catch {
            // Silently fail - connection check will handle the isConnected state
        }
    }

    func sendMessage(
        model: String,
        messages: [Message],
        temperature: Double = 0.7,
        options: [String: Any] = [:],
        completion: @escaping (Result<(content: String, metrics: MessageMetrics), Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let chatMessages = messages.map { msg in
            ChatRequest.ChatMessage(role: msg.role.rawValue, content: msg.content)
        }
        
        // Convert options to AnyCodable
        let encodableOptions = options.isEmpty ? nil : options.mapValues { AnyCodable($0) }

        let chatRequest = ChatRequest(
            model: model,
            messages: chatMessages,
            stream: false,
            temperature: temperature,
            options: encodableOptions
        )

        do {
            request.httpBody = try JSONEncoder().encode(chatRequest)
        } catch {
            completion(.failure(error))
            return
        }

        let startTime = Date()
        var firstByteTime: Date?

        session.dataTask(with: request) { [weak self] data, response, error in
            if firstByteTime == nil {
                firstByteTime = Date()
            }

            if let error = error {
                // Update connection status on error
                Task { @MainActor in
                    self?.isConnected = false
                }
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received from server"])))
                return
            }

            // Check HTTP response status
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let errorMessage = "Server returned status code \(httpResponse.statusCode)"
                completion(.failure(NSError(domain: "HTTP Error", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }

            let endTime = Date()
            let totalDuration = endTime.timeIntervalSince(startTime)
            let timeToFirstToken = (firstByteTime ?? startTime).timeIntervalSince(startTime)

            do {
                let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
                if let content = chatResponse.choices.first?.message.content {
                    // Update connection status on success
                    Task { @MainActor in
                        self?.isConnected = true
                    }

                    // Calculate metrics
                    let totalTokens = chatResponse.usage?.completion_tokens ?? 0
                    let tokensPerSecond = totalDuration > 0 ? Double(totalTokens) / totalDuration : 0

                    let metrics = MessageMetrics(
                        totalTokens: totalTokens,
                        tokensPerSecond: tokensPerSecond,
                        timeToFirstToken: timeToFirstToken,
                        totalDuration: totalDuration
                    )

                    completion(.success((content: content, metrics: metrics)))
                } else {
                    completion(.failure(NSError(domain: "Invalid Response", code: -1, userInfo: [NSLocalizedDescriptionKey: "No content in response"])))
                }
            } catch {
                completion(.failure(NSError(domain: "Decoding Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response: \(error.localizedDescription)"])))
            }
        }.resume()
    }
    
    /// Send message with vision model support for images and OCR for PDFs
    func sendMessageWithVision(
        model: String = "llava:7b",
        prompt: String,
        attachments: [MessageAttachment],
        temperature: Double = 0.7,
        returnExtractedText: Bool = false,
        completion: @escaping (Result<(content: String, metrics: MessageMetrics, extractedText: String?), Error>) -> Void
    ) {
        let startTime = Date()
        
        // Separate PDFs and images
        let pdfAttachments = attachments.filter { $0.type == .pdf }
        let imageAttachments = attachments.filter { $0.type == .image }
        
        var combinedResponse = ""
        var processingErrors: [String] = []
        
        // Process PDFs with OCR
        if !pdfAttachments.isEmpty {
            for pdfAttachment in pdfAttachments {
                if let extractedText = extractTextFromPDF(data: pdfAttachment.data) {
                    if !extractedText.isEmpty {
                        combinedResponse += "📄 **\(pdfAttachment.fileName)**\n\n"
                        combinedResponse += extractedText
                        combinedResponse += "\n\n---\n\n"
                    } else {
                        processingErrors.append("Could not extract text from \(pdfAttachment.fileName)")
                    }
                } else {
                    processingErrors.append("Failed to process \(pdfAttachment.fileName)")
                }
            }
        }
        
        // Process images with VLM
        if !imageAttachments.isEmpty {
            guard let url = URL(string: "\(baseURL)/api/generate") else {
                completion(.failure(NSError(domain: "Invalid URL", code: -1)))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Convert images to base64
            var images: [String] = []
            for attachment in imageAttachments {
                let base64String = attachment.data.base64EncodedString()
                images.append(base64String)
            }
            
            // Build the prompt for images
            let imageContext = imageAttachments.count == 1 ? "this image" : "these \(imageAttachments.count) images"
            let imagePrompt = prompt.isEmpty ? "Please analyze \(imageContext) and describe what you see in detail." : prompt
            
            // Create vision request
            let visionRequest: [String: Any] = [
                "model": model,
                "prompt": imagePrompt,
                "images": images,
                "stream": false,
                "options": [
                    "temperature": temperature
                ]
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: visionRequest)
            } catch {
                completion(.failure(error))
                return
            }
            
            var firstByteTime: Date?
            
            session.dataTask(with: request) { [weak self] data, response, error in
                if firstByteTime == nil {
                    firstByteTime = Date()
                }
                
                if let error = error {
                    Task { @MainActor in
                        self?.isConnected = false
                    }
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "No data received", code: -1)))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    let errorMessage = "Server returned status code \(httpResponse.statusCode)"
                    completion(.failure(NSError(domain: "HTTP Error", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                    return
                }
                
                let endTime = Date()
                let totalDuration = endTime.timeIntervalSince(startTime)
                let timeToFirstToken = (firstByteTime ?? startTime).timeIntervalSince(startTime)
                
                do {
                    let visionResponse = try JSONDecoder().decode(VisionResponse.self, from: data)
                    
                    Task { @MainActor in
                        self?.isConnected = true
                    }
                    
                    // Combine image analysis with PDF text
                    if !combinedResponse.isEmpty {
                        combinedResponse += "🖼️ **Image Analysis**\n\n"
                    }
                    combinedResponse += visionResponse.response
                    
                    // Add any processing errors
                    if !processingErrors.isEmpty {
                        combinedResponse += "\n\n⚠️ **Processing Notes:**\n"
                        for error in processingErrors {
                            combinedResponse += "- \(error)\n"
                        }
                    }
                    
                    let estimatedTokens = combinedResponse.split(separator: " ").count
                    let tokensPerSecond = totalDuration > 0 ? Double(estimatedTokens) / totalDuration : 0
                    
                    let metrics = MessageMetrics(
                        totalTokens: estimatedTokens,
                        tokensPerSecond: tokensPerSecond,
                        timeToFirstToken: timeToFirstToken,
                        totalDuration: totalDuration
                    )
                    
                    // Return combined response with extracted text if requested
                    let extractedText = returnExtractedText ? combinedResponse : nil
                    completion(.success((content: combinedResponse, metrics: metrics, extractedText: extractedText)))
                } catch {
                    completion(.failure(NSError(domain: "Decoding Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode vision response: \(error.localizedDescription)"])))
                }
            }.resume()
        } else {
            // Only PDFs, no VLM needed - send extracted text to regular LLM for Q&A
            guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
                completion(.failure(NSError(domain: "Invalid URL", code: -1)))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Build context from extracted PDF text
            var contextMessage = "Here is the content from the uploaded document(s):\n\n"
            contextMessage += combinedResponse
            
            // Add user's question
            let userQuestion = prompt.isEmpty ? "Please summarize the key points from this document." : prompt
            
            // Create chat messages with document context
            let chatMessages = [
                ChatRequest.ChatMessage(role: "system", content: "You are a helpful assistant analyzing documents. Answer questions based on the provided document content."),
                ChatRequest.ChatMessage(role: "user", content: contextMessage),
                ChatRequest.ChatMessage(role: "user", content: userQuestion)
            ]
            
            let chatRequest = ChatRequest(
                model: "gemma3:4b",  // Use default model for text analysis
                messages: chatMessages,
                stream: false,
                temperature: temperature,
                options: nil
            )
            
            do {
                request.httpBody = try JSONEncoder().encode(chatRequest)
            } catch {
                completion(.failure(error))
                return
            }
            
            var firstByteTime: Date?
            
            session.dataTask(with: request) { [weak self] data, response, error in
                if firstByteTime == nil {
                    firstByteTime = Date()
                }
                
                if let error = error {
                    Task { @MainActor in
                        self?.isConnected = false
                    }
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "No data received", code: -1)))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    let errorMessage = "Server returned status code \(httpResponse.statusCode)"
                    completion(.failure(NSError(domain: "HTTP Error", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                    return
                }
                
                let endTime = Date()
                let totalDuration = endTime.timeIntervalSince(startTime)
                let timeToFirstToken = (firstByteTime ?? startTime).timeIntervalSince(startTime)
                
                do {
                    let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
                    
                    Task { @MainActor in
                        self?.isConnected = true
                    }
                    
                    if let content = chatResponse.choices.first?.message.content {
                        // Add processing errors if any
                        var finalResponse = content
                        if !processingErrors.isEmpty {
                            finalResponse += "\n\n⚠️ **Processing Notes:**\n"
                            for error in processingErrors {
                                finalResponse += "- \(error)\n"
                            }
                        }
                        
                        let totalTokens = chatResponse.usage?.completion_tokens ?? 0
                        let tokensPerSecond = totalDuration > 0 ? Double(totalTokens) / totalDuration : 0
                        
                        let metrics = MessageMetrics(
                            totalTokens: totalTokens,
                            tokensPerSecond: tokensPerSecond,
                            timeToFirstToken: timeToFirstToken,
                            totalDuration: totalDuration
                        )
                        
                        // Return response with extracted PDF text if requested
                        let extractedText = returnExtractedText ? combinedResponse : nil
                        completion(.success((content: finalResponse, metrics: metrics, extractedText: extractedText)))
                    } else {
                        completion(.failure(NSError(domain: "Invalid Response", code: -1, userInfo: [NSLocalizedDescriptionKey: "No content in response"])))
                    }
                } catch {
                    completion(.failure(NSError(domain: "Decoding Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response: \(error.localizedDescription)"])))
                }
            }.resume()
        }
    }
    
    /// Extract text from PDF using Vision framework OCR
    private func extractTextFromPDF(data: Data) -> String? {
        guard let pdfDocument = PDFDocument(data: data) else {
            return nil
        }
        
        var extractedText = ""
        let pageCount = pdfDocument.pageCount
        
        // Process up to first 5 pages to avoid excessive processing time and UI freezing
        let pagesToProcess = min(pageCount, 5)
        
        for pageIndex in 0..<pagesToProcess {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            // First try to extract text directly (if PDF has selectable text)
            if let pageText = page.string, !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                extractedText += "--- Page \(pageIndex + 1) ---\n\n"
                extractedText += pageText
                extractedText += "\n\n"
            } else {
                // If no text, use OCR on rendered page
                if let ocrText = performOCROnPage(page) {
                    extractedText += "--- Page \(pageIndex + 1) (OCR) ---\n\n"
                    extractedText += ocrText
                    extractedText += "\n\n"
                }
            }
        }
        
        if pageCount > 5 {
            extractedText += "\n\n[Note: Only first 5 pages of \(pageCount) total pages were processed for performance]\n"
        }
        
        return extractedText.isEmpty ? nil : extractedText
    }
    
    /// Perform OCR on a PDF page using Vision framework
    private func performOCROnPage(_ page: PDFPage) -> String? {
        let pageRect = page.bounds(for: .mediaBox)
        
        // Render page to image at 2x resolution for better OCR
        let scaleFactor: CGFloat = 2.0
        let scaledSize = CGSize(
            width: pageRect.width * scaleFactor,
            height: pageRect.height * scaleFactor
        )
        
        let image = NSImage(size: scaledSize)
        image.lockFocus()
        
        if let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.scaleBy(x: scaleFactor, y: scaleFactor)
            context.translateBy(x: 0, y: pageRect.size.height)
            context.scaleBy(x: 1.0, y: -1.0)
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()
        }
        
        image.unlockFocus()
        
        // Convert to CGImage for Vision
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmapImage.cgImage else {
            return nil
        }
        
        // Perform OCR using Vision
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
            
            guard let observations = request.results else {
                return nil
            }
            
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            return recognizedText.isEmpty ? nil : recognizedText
        } catch {
            print("OCR Error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Render first page of PDF as base64 encoded image at high resolution
    private func renderPDFFirstPage(from data: Data) -> String? {
        guard let pdfDocument = PDFDocument(data: data),
              let firstPage = pdfDocument.page(at: 0) else {
            return nil
        }
        
        let pageRect = firstPage.bounds(for: .mediaBox)
        
        // Scale up for better resolution (2x scale, max 1600px width)
        let scaleFactor: CGFloat = min(2.0, 1600.0 / pageRect.width)
        let scaledSize = CGSize(
            width: pageRect.width * scaleFactor,
            height: pageRect.height * scaleFactor
        )
        
        // Create high-resolution image representation
        let image = NSImage(size: scaledSize)
        image.lockFocus()
        
        if let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            
            // Scale the context for high resolution
            context.scaleBy(x: scaleFactor, y: scaleFactor)
            
            // Flip coordinate system for PDF rendering
            context.translateBy(x: 0, y: pageRect.size.height)
            context.scaleBy(x: 1.0, y: -1.0)
            
            // Draw the PDF page
            firstPage.draw(with: .mediaBox, to: context)
            
            context.restoreGState()
        }
        
        image.unlockFocus()
        
        // Convert to JPEG with good quality (smaller than PNG, still readable)
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
            return nil
        }
        
        return jpegData.base64EncodedString()
    }
}

struct VisionResponse: Codable {
    let model: String
    let response: String
    let done: Bool
}

struct ModelsResponse: Codable {
    let models: [Model]

    struct Model: Codable {
        let name: String
    }
}
