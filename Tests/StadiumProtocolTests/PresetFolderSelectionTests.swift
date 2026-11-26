import XCTest
@testable import StadiumProtocol
final class PresetFolderSelectionTests:XCTestCase {
    func folder(_ id:Int,_ preset:Int)->PresetFolder {
        PresetFolder(reference:.object(["type":.int(1003),"cid_":.int(Int64(id))]),contents:.array([.object(["type":.int(1),"rcid":.int(Int64(preset)),"posi":.int(0)])]))!
    }
    func testRestoreLastFolderAfterDelayedInventoryEvenWhenAnotherContainsCurrentPreset() {
        let folders=[folder(101,1),folder(102,2)]
        XCTAssertEqual(PresetFolderSelection.restore(folders:[],remembered:102,presetID:1),-2)
        XCTAssertEqual(PresetFolderSelection.restore(folders:folders,remembered:102,presetID:1),102)
    }
    func testMissingPreferenceUsesCurrentPresetAndDeletedFolderFallsBack() {
        let folders=[folder(101,1),folder(102,2)]
        XCTAssertEqual(PresetFolderSelection.restore(folders:folders,remembered:nil,presetID:2),102)
        XCTAssertEqual(PresetFolderSelection.restore(folders:folders,remembered:999,presetID:2),102)
        XCTAssertEqual(PresetFolderSelection.restore(folders:folders,remembered:-2,presetID:2),-2)
    }
    func testDuplicateMembershipKeepsWorkingFolderAndUnknownPresetUsesAll() {
        let folders=[folder(101,1),folder(102,1)]
        XCTAssertEqual(PresetFolderSelection.follow(folders:folders,preferred:102,presetID:1),102)
        XCTAssertEqual(PresetFolderSelection.follow(folders:folders,preferred:102,presetID:99),-2)
    }
}
