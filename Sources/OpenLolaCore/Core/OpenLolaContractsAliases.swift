// Provides public contract operations used by the surrounding workflow, keeping this focused compatibility or analysis logic outside the primary execution path.
import OpenLolaContracts

// OpenLolaContracts is the canonical home for framework-free report contracts.
// OpenLolaCore keeps this small alias set for source compatibility with existing
// callers and reports. Add new shared contracts to OpenLolaContracts first, then
// alias them here only when OpenLolaCore compatibility requires it.
/// Re-exports the framework-free measurement-methodology contract for Open LoLa Core callers.
public typealias MeasurementMethodology = OpenLolaContracts.MeasurementMethodology
/// Re-exports the framework-free measurement-verdict contract for Open LoLa Core callers.
public typealias MeasurementVerdict = OpenLolaContracts.MeasurementVerdict
/// Re-exports deterministic pretty-JSON encoding for Open LoLa Core report types.
public typealias PrettyJSONCodable = OpenLolaContracts.PrettyJSONCodable
/// Re-exports the framework-free report-run-mode contract for Open LoLa Core callers.
public typealias ReportRunMode = OpenLolaContracts.ReportRunMode
/// Re-exports the framework-free receive-buffer profile for Open LoLa Core callers.
public typealias RxBufferProfile = OpenLolaContracts.RxBufferProfile
