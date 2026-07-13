import Testing
import Foundation
@testable import Murmurix

// In-memory audio decoding for the API server, plus the serial transcription queue.

struct AudioDecoderTests {

    /// Builds a minimal PCM16 WAV in memory.
    private func makeWav(samples: [Int16], sampleRate: Int, channels: Int) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        let dataSize = UInt32(samples.count * 2)
        d.append("RIFF".data(using: .ascii)!); u32(36 + dataSize); d.append("WAVE".data(using: .ascii)!)
        d.append("fmt ".data(using: .ascii)!); u32(16); u16(1); u16(UInt16(channels))
        u32(UInt32(sampleRate)); u32(UInt32(sampleRate * channels * 2)); u16(UInt16(channels * 2)); u16(16)
        d.append("data".data(using: .ascii)!); u32(dataSize)
        for s in samples { u16(UInt16(bitPattern: s)) }
        return d
    }

    @Test func decodesMono16kPcm16() throws {
        let wav = makeWav(samples: [16384, -16384, 0], sampleRate: 16000, channels: 1)
        let out = try AudioDecoder.decodeToMonoFloat16k(wav)
        #expect(out.count == 3)
        #expect(abs(out[0] - 0.5) < 0.001)
        #expect(abs(out[1] - (-0.5)) < 0.001)
        #expect(abs(out[2]) < 0.001)
    }

    @Test func downmixesStereoToMono() throws {
        // One stereo frame: L=16384 (0.5), R=0 → mono average 0.25.
        let wav = makeWav(samples: [16384, 0], sampleRate: 16000, channels: 2)
        let out = try AudioDecoder.decodeToMonoFloat16k(wav)
        #expect(out.count == 1)
        #expect(abs(out[0] - 0.25) < 0.001)
    }

    @Test func resamplesNon16kToRoughlyDoubledAt8k() throws {
        // 8 kHz → 16 kHz doubles the sample count (linear resampler).
        let wav = makeWav(samples: Array(repeating: 8192, count: 8), sampleRate: 8000, channels: 1)
        let out = try AudioDecoder.decodeToMonoFloat16k(wav)
        #expect(out.count == 16)
    }

    @Test func rawFloat32PassesThrough() throws {
        let floats: [Float] = [0.1, -0.2, 0.3]
        var data = Data()
        for f in floats { withUnsafeBytes(of: f.bitPattern.littleEndian) { data.append(contentsOf: $0) } }
        let out = try AudioDecoder.decodeToMonoFloat16k(data)
        #expect(out.count == 3)
        #expect(abs(out[0] - 0.1) < 0.0001)
        #expect(abs(out[2] - 0.3) < 0.0001)
    }

    @Test func emptyDataThrows() {
        #expect(throws: (any Error).self) {
            _ = try AudioDecoder.decodeToMonoFloat16k(Data())
        }
    }

    @Test func unsupportedBitDepthThrows() {
        // 24-bit PCM WAV header — data readers only support 16-bit int / 32-bit float.
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        d.append("RIFF".data(using: .ascii)!); u32(36); d.append("WAVE".data(using: .ascii)!)
        d.append("fmt ".data(using: .ascii)!); u32(16); u16(1); u16(1); u32(16000); u32(48000); u16(3); u16(24)
        d.append("data".data(using: .ascii)!); u32(3); d.append(Data([1, 2, 3]))
        #expect(throws: (any Error).self) {
            _ = try AudioDecoder.decodeToMonoFloat16k(d)
        }
    }
}

struct SerialTranscriberTests {

    @Test func returnsServiceResult() async throws {
        let mock = MockTranscriptionService()
        mock.transcriptionResult = .success("hello")
        let serial = SerialTranscriber(service: mock)

        let text = try await serial.transcribe(samples: [0.1, 0.2], language: "ru", model: "small")
        #expect(text == "hello")
        #expect(mock.lastSamples == [0.1, 0.2])
    }

    @Test func serializesConcurrentCalls() async throws {
        // All calls should complete and return the same result even when fired together.
        let mock = MockTranscriptionService()
        mock.transcriptionResult = .success("ok")
        mock.transcriptionDelay = 0.02
        let serial = SerialTranscriber(service: mock)

        try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<5 {
                group.addTask { try await serial.transcribe(samples: [0.0], language: "ru", model: "small") }
            }
            var count = 0
            for try await result in group {
                #expect(result == "ok")
                count += 1
            }
            #expect(count == 5)
        }
        #expect(mock.transcribeCallCount == 5)
    }
}

/// End-to-end HTTP tests: they start a real APIServer on loopback and drive it with
/// URLSession over a genuine WAV payload. Transcription itself is mocked (WhisperKit
/// models aren't available in the test environment), so these prove the server, routing
/// and in-memory WAV decoding — the real-model path is verified live via curl.
struct APIServerHTTPTests {

    /// A genuine PCM16 16 kHz mono WAV containing a short sine tone (non-silent).
    private func makeRealWav(sampleCount: Int = 8000) -> Data {
        var samples = [Int16]()
        samples.reserveCapacity(sampleCount)
        for i in 0..<sampleCount {
            let v = sin(Double(i) * 2.0 * Double.pi * 440.0 / 16000.0)
            samples.append(Int16(v * 16384))
        }
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        let dataSize = UInt32(samples.count * 2)
        d.append("RIFF".data(using: .ascii)!); u32(36 + dataSize); d.append("WAVE".data(using: .ascii)!)
        d.append("fmt ".data(using: .ascii)!); u32(16); u16(1); u16(1); u32(16000); u32(32000); u16(2); u16(16)
        d.append("data".data(using: .ascii)!); u32(dataSize)
        for s in samples { u16(UInt16(bitPattern: s)) }
        return d
    }

    private func startServer(port: UInt16, mock: MockTranscriptionService) async throws -> APIServer {
        let server = APIServer(
            transcriptionService: mock,
            modelsProvider: { (installed: ["small", "base"], loaded: ["small"]) }
        )
        server.start(port: port)
        // Wait until it's actually accepting connections.
        let healthURL = URL(string: "http://127.0.0.1:\(port)/health")!
        for _ in 0..<50 {
            var req = URLRequest(url: healthURL)
            req.timeoutInterval = 0.5
            if let (_, resp) = try? await URLSession.shared.data(for: req),
               (resp as? HTTPURLResponse)?.statusCode == 200 {
                return server
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw APITestError.serverNeverStarted
    }

    private func post(port: UInt16, path: String, body: Data) async throws -> (Int, [String: Any]) {
        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!)
        req.httpMethod = "POST"
        req.httpBody = body
        req.timeoutInterval = 5
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return (status, json)
    }

    @Test func transcribesRealWavOverHTTP() async throws {
        let port: UInt16 = 52001
        let mock = MockTranscriptionService()
        mock.transcriptionResult = .success("привет мир")
        let server = try await startServer(port: port, mock: mock)
        defer { server.stop() }

        let wav = makeRealWav()
        let (status, json) = try await post(
            port: port,
            path: "/v1/transcribe?model=small&language=ru",
            body: wav
        )

        #expect(status == 200)
        #expect(json["text"] as? String == "привет мир")
        // The server decoded the real WAV into a non-empty buffer before transcribing.
        #expect(mock.lastSamples?.isEmpty == false)
        #expect((mock.lastSamples?.count ?? 0) > 1000)
        #expect(mock.lastLanguage == "ru")
    }

    @Test func missingModelParamReturns400() async throws {
        let port: UInt16 = 52002
        let mock = MockTranscriptionService()
        let server = try await startServer(port: port, mock: mock)
        defer { server.stop() }

        let (status, json) = try await post(port: port, path: "/v1/transcribe?language=ru", body: makeRealWav())
        #expect(status == 400)
        #expect((json["error"] as? String)?.isEmpty == false)
        #expect(mock.transcribeCallCount == 0)
    }

    @Test func emptyBodyReturns400() async throws {
        let port: UInt16 = 52003
        let mock = MockTranscriptionService()
        let server = try await startServer(port: port, mock: mock)
        defer { server.stop() }

        let (status, _) = try await post(port: port, path: "/v1/transcribe?model=small", body: Data())
        #expect(status == 400)
        #expect(mock.transcribeCallCount == 0)
    }

    @Test func modelsEndpointListsInstalledAndLoaded() async throws {
        let port: UInt16 = 52004
        let mock = MockTranscriptionService()
        let server = try await startServer(port: port, mock: mock)
        defer { server.stop() }

        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/v1/models")!)
        req.timeoutInterval = 5
        let (data, resp) = try await URLSession.shared.data(for: req)
        #expect((resp as? HTTPURLResponse)?.statusCode == 200)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        #expect(json["installed"] as? [String] == ["small", "base"])
        #expect(json["loaded"] as? [String] == ["small"])
    }
}

private enum APITestError: Error { case serverNeverStarted }
