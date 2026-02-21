import Testing
@testable import Murmurix

struct RecordingFlowReducerTests {
    @Test func idleToggleStartsRecording() {
        let transition = RecordingFlowReducer.reduce(
            state: .idle,
            event: .toggle(mode: .local(model: "small"))
        )

        #expect(transition == .startRecording(mode: .local(model: "small")))
    }

    @Test func recordingToggleStopsRecording() {
        let transition = RecordingFlowReducer.reduce(
            state: .recording,
            event: .toggle(mode: .openai)
        )

        #expect(transition == .stopRecording)
    }

    @Test func recordingCancelStopsWithoutTranscription() {
        let transition = RecordingFlowReducer.reduce(
            state: .recording,
            event: .cancelRecording
        )

        #expect(transition == .cancelRecording)
    }

    @Test func transcribingCancelStopsTranscription() {
        let transition = RecordingFlowReducer.reduce(
            state: .transcribing,
            event: .cancelTranscription
        )

        #expect(transition == .cancelTranscription)
    }

    @Test func transcribingToggleIsIgnored() {
        let transition = RecordingFlowReducer.reduce(
            state: .transcribing,
            event: .toggle(mode: .gemini)
        )

        #expect(transition == .ignore)
    }

    @Test func idleCancelRecordingIsIgnored() {
        let transition = RecordingFlowReducer.reduce(
            state: .idle,
            event: .cancelRecording
        )

        #expect(transition == .ignore)
    }

    @Test func recordingCancelTranscriptionIsIgnored() {
        let transition = RecordingFlowReducer.reduce(
            state: .recording,
            event: .cancelTranscription
        )

        #expect(transition == .ignore)
    }
}
