import OpenLolaContracts

// OpenLolaContracts is the canonical home for framework-free report contracts.
// OpenLolaCore keeps this small alias set for source compatibility with existing
// callers and reports. Add new shared contracts to OpenLolaContracts first, then
// alias them here only when OpenLolaCore compatibility requires it.
public typealias MeasurementMethodology = OpenLolaContracts.MeasurementMethodology
public typealias MeasurementVerdict = OpenLolaContracts.MeasurementVerdict
public typealias PrettyJSONCodable = OpenLolaContracts.PrettyJSONCodable
public typealias ReportRunMode = OpenLolaContracts.ReportRunMode
public typealias RxBufferProfile = OpenLolaContracts.RxBufferProfile
