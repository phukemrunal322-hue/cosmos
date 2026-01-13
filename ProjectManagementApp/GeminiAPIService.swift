import Foundation

enum GeminiError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Unable to parse API response"
        case .apiError(let message):
            return "API Error: \(message)"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        }
    }
}

class GeminiAPIService {
    private let apiKey = "AIzaSyAD2bNpt0GZYpn4-wkKLYraLVt3G8jovXY"
    
    // Multiple models to try in order of preference (supported on v1 generateContent)
    private let models = [
        "gemini-1.5-flash",
        "gemini-1.5-pro"
    ]
    
    private func getBaseURL(for model: String) -> String {
        return "https://generativelanguage.googleapis.com/v1/models/\(model):generateContent"
    }
    
    func generateDailyReport(employeeName: String, projectName: String, date: String, tasksDone: String) async throws -> String {
        var lastError: Error?
        
        // Try each model in sequence
        for (index, model) in models.enumerated() {
            print("Attempting to use model: \(model) (attempt \(index + 1)/\(models.count))")
            
            do {
                let report = try await generateWithModel(
                    model: model,
                    employeeName: employeeName,
                    projectName: projectName,
                    date: date,
                    tasksDone: tasksDone
                )
                print("Successfully generated report using model: \(model)")
                return report
            } catch {
                print("Failed with model \(model): \(error.localizedDescription)")
                lastError = error
                
                // If this isn't the last model, continue to next one
                if index < models.count - 1 {
                    print("Trying next model...")
                    continue
                }
            }
        }
        
        // If all models failed, throw the last error
        throw lastError ?? GeminiError.invalidResponse
    }
    
    private func generateWithModel(model: String, employeeName: String, projectName: String, date: String, tasksDone: String) async throws -> String {
        let prompt = """
        Create a simple daily report using the following form content:
        
        Employee Name: \(employeeName)
        Project Name: \(projectName)
        Date: \(date)
        Tasks Completed Today: \(tasksDone)
        
        Format it as a brief, clear daily report with these sections:
        - Employee and project information
        - Date
        - Tasks completed
        
        Keep it concise and professional.
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 1024
            ]
        ]
        
        let baseURL = getBaseURL(for: model)
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw GeminiError.networkError(error)
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GeminiError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        
        // Log response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("API Response Status: \(httpResponse.statusCode)")
            print("API Response: \(responseString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("API Error Message: \(message)")
                throw GeminiError.apiError(message)
            }
            throw GeminiError.apiError("HTTP Status: \(httpResponse.statusCode)")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("Failed to parse JSON response")
            throw GeminiError.invalidResponse
        }
        
        print("Parsed JSON: \(json)")
        
        if let candidates = json["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let firstPart = parts.first,
           let text = firstPart["text"] as? String {
            print("Successfully extracted text from response")
            return text
        }
        
        print("Failed to extract text from candidates")
        throw GeminiError.invalidResponse
    }
    
    // Generate Minutes of Meeting
    func generateMinutesOfMeeting(
        projectName: String,
        date: String,
        startTime: String,
        endTime: String,
        venue: String,
        internalAttendees: String,
        externalAttendees: String,
        agenda: String,
        discussion: String,
        actionItems: String,
        preparedBy: String
    ) async throws -> String {
        var lastError: Error?
        
        // Try each model in sequence
        for (index, model) in models.enumerated() {
            print("Attempting to use model: \(model) for MOM generation (attempt \(index + 1)/\(models.count))")
            
            do {
                let mom = try await generateMOMWithModel(
                    model: model,
                    projectName: projectName,
                    date: date,
                    startTime: startTime,
                    endTime: endTime,
                    venue: venue,
                    internalAttendees: internalAttendees,
                    externalAttendees: externalAttendees,
                    agenda: agenda,
                    discussion: discussion,
                    actionItems: actionItems,
                    preparedBy: preparedBy
                )
                print("Successfully generated MOM using model: \(model)")
                return mom
            } catch {
                print("Failed with model \(model): \(error.localizedDescription)")
                lastError = error
                
                // If this isn't the last model, continue to next one
                if index < models.count - 1 {
                    print("Trying next model...")
                    continue
                }
            }
        }
        
        // If all models failed, throw the last error
        throw lastError ?? GeminiError.invalidResponse
    }
    
    private func generateMOMWithModel(
        model: String,
        projectName: String,
        date: String,
        startTime: String,
        endTime: String,
        venue: String,
        internalAttendees: String,
        externalAttendees: String,
        agenda: String,
        discussion: String,
        actionItems: String,
        preparedBy: String
    ) async throws -> String {
        let prompt = """
        You are an AI assistant that analyzes meeting discussions.
        
        Analyze the following 'Discussion Points' and extract the following structured information:
        1. Summary: A brief summary of what was discussed.
        2. Key Points: A list of key topics or points raised.
        3. Decisions Taken: A list of any decisions made.
        4. Next Steps: A list of agreed next steps or follow-ups looking forward.
        
        Discussion Points:
        \(discussion)
        
        IMPORTANT: Return the result correctly formatted as a JSON object with keys: 'summary', 'keyPoints' (array of strings), 'decisions' (array of strings), 'nextSteps' (array of strings).
        
        - If the input is too short or nonsensical (e.g., "s", "test"), DO NOT return an error. Instead, create a best-guess summary (e.g., "Discussion regarding [input]") and leave arrays empty or with one distinct point.
        - The output MUST be valid JSON.
        - Do not include markdown formatting like ```json ... ```, just return the raw JSON string.
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 2048
            ]
        ]
        
        let baseURL = getBaseURL(for: model)
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw GeminiError.networkError(error)
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GeminiError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        
        // Log response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("API Response Status: \(httpResponse.statusCode)")
            print("API Response: \(responseString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("API Error Message: \(message)")
                throw GeminiError.apiError(message)
            }
            throw GeminiError.apiError("HTTP Status: \(httpResponse.statusCode)")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("Failed to parse JSON response")
            throw GeminiError.invalidResponse
        }
        
        print("Parsed JSON: \(json)")
        
        if let candidates = json["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let firstPart = parts.first,
           let text = firstPart["text"] as? String {
            print("Successfully extracted MOM text from response")
            return text
        }
        
        print("Failed to extract text from candidates")
        throw GeminiError.invalidResponse
    }
}
