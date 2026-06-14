import Foundation

@main
struct ModelDescriptorTests {
    static func main() throws {
        try privateCloudLaneUsesBroadSectionTitle()
        print("ModelDescriptorTests passed")
    }

    private static func privateCloudLaneUsesBroadSectionTitle() throws {
        try expect(
            ModelLane.privateCloud.title == "Apple Cloud",
            "private cloud lane should use a broader section title than the Private Cloud Compute model"
        )
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if condition == false {
            throw TestFailure(message)
        }
    }

    private struct TestFailure: Error, CustomStringConvertible {
        var description: String

        init(_ description: String) {
            self.description = description
        }
    }
}
