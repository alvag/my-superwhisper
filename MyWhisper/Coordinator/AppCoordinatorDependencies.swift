// Stub protocols — implemented in Plans 03 and 04
protocol AudioRecorderProtocol: AnyObject {
    func startStub()
    func stopStub()
    func cancelStub()
}

protocol TextInjectorProtocol: AnyObject {
    func inject(_ text: String) async
}

protocol OverlayWindowControllerProtocol: AnyObject {
    func show()
    func hide()
}
