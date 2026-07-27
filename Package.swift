// swift-tools-version: 6.0
// Declares OpenLola package products and target wiring, keeping build boundaries explicit for local and release builds.

import PackageDescription

#if os(Linux)
// The Swift package is macOS-only because OpenLolaCore links AppKit,
// AVFoundation, and CoreAudio. The first-class Linux connector is the separate
// Python package under linux_connector/.
#endif

func executableInfoPlistLinkerSettings(_ path: String) -> [LinkerSetting] {
    [
        .unsafeFlags([
            "-Xlinker", "-sectcreate",
            "-Xlinker", "__TEXT",
            "-Xlinker", "__info_plist",
            "-Xlinker", path
        ])
    ]
}

let package = Package(
    name: "open-lola",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OpenLolaCore",
            targets: ["OpenLolaCore", "COpenLolaAtomics", "CJpegXSReference", "COpus"]
        ),
        .library(
            name: "OpenLolaContracts",
            targets: ["OpenLolaContracts"]
        ),
        .library(
            name: "OpenLolaAppSupport",
            targets: ["OpenLolaAppSupport"]
        ),
        .executable(
            name: "open-lola",
            targets: ["open-lola"]
        ),
        .executable(
            name: "open-lola-app",
            targets: ["open-lola-app"]
        )
    ],
    targets: [
        .target(
            name: "OpenLolaContracts",
            path: "Sources/OpenLolaContracts"
        ),
        .target(
            name: "OpenLolaCore",
            dependencies: ["OpenLolaContracts", "COpenLolaAtomics", "CJpegXSReference", "COpus"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreImage"),
                .linkedFramework("ImageIO"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .target(
            name: "OpenLolaAppSupport",
            dependencies: ["OpenLolaCore", "COpenLolaAtomics"],
            path: "Sources/open-lola-app",
            exclude: ["Info.plist", "open-lola-app.entitlements"]
        ),
        .target(
            name: "COpenLolaAtomics",
            path: "Sources/COpenLolaAtomics",
            publicHeadersPath: "include"
        ),
        .target(
            name: "CJpegXSReference",
            path: "Sources/xs_ref_sw_ed2/libjxs",
            exclude: ["CMakeLists.txt", "src/msbpack.c"],
            publicHeadersPath: "public",
            cSettings: [
                .headerSearchPath("src")
            ]
        ),
        .target(
            name: "COpus",
            path: "Sources/opus-1.5.2",
            sources: [
                "openlola_bridge/COpusBridge.c",
                "src/opus.c",
                "src/opus_decoder.c",
                "src/opus_encoder.c",
                "src/extensions.c",
                "src/opus_multistream.c",
                "src/opus_multistream_encoder.c",
                "src/opus_multistream_decoder.c",
                "src/repacketizer.c",
                "src/opus_projection_encoder.c",
                "src/opus_projection_decoder.c",
                "src/mapping_matrix.c",
                "src/analysis.c",
                "src/mlp.c",
                "src/mlp_data.c",
                "celt/bands.c",
                "celt/celt.c",
                "celt/celt_encoder.c",
                "celt/celt_decoder.c",
                "celt/cwrs.c",
                "celt/entcode.c",
                "celt/entdec.c",
                "celt/entenc.c",
                "celt/kiss_fft.c",
                "celt/laplace.c",
                "celt/mathops.c",
                "celt/mdct.c",
                "celt/modes.c",
                "celt/pitch.c",
                "celt/celt_lpc.c",
                "celt/quant_bands.c",
                "celt/rate.c",
                "celt/vq.c",
                "silk/CNG.c",
                "silk/code_signs.c",
                "silk/init_decoder.c",
                "silk/decode_core.c",
                "silk/decode_frame.c",
                "silk/decode_parameters.c",
                "silk/decode_indices.c",
                "silk/decode_pulses.c",
                "silk/decoder_set_fs.c",
                "silk/dec_API.c",
                "silk/enc_API.c",
                "silk/encode_indices.c",
                "silk/encode_pulses.c",
                "silk/gain_quant.c",
                "silk/interpolate.c",
                "silk/LP_variable_cutoff.c",
                "silk/NLSF_decode.c",
                "silk/NSQ.c",
                "silk/NSQ_del_dec.c",
                "silk/PLC.c",
                "silk/shell_coder.c",
                "silk/tables_gain.c",
                "silk/tables_LTP.c",
                "silk/tables_NLSF_CB_NB_MB.c",
                "silk/tables_NLSF_CB_WB.c",
                "silk/tables_other.c",
                "silk/tables_pitch_lag.c",
                "silk/tables_pulses_per_block.c",
                "silk/VAD.c",
                "silk/control_audio_bandwidth.c",
                "silk/quant_LTP_gains.c",
                "silk/VQ_WMat_EC.c",
                "silk/HP_variable_cutoff.c",
                "silk/NLSF_encode.c",
                "silk/NLSF_VQ.c",
                "silk/NLSF_unpack.c",
                "silk/NLSF_del_dec_quant.c",
                "silk/process_NLSFs.c",
                "silk/stereo_LR_to_MS.c",
                "silk/stereo_MS_to_LR.c",
                "silk/check_control_input.c",
                "silk/control_SNR.c",
                "silk/init_encoder.c",
                "silk/control_codec.c",
                "silk/A2NLSF.c",
                "silk/ana_filt_bank_1.c",
                "silk/biquad_alt.c",
                "silk/bwexpander_32.c",
                "silk/bwexpander.c",
                "silk/debug.c",
                "silk/decode_pitch.c",
                "silk/inner_prod_aligned.c",
                "silk/lin2log.c",
                "silk/log2lin.c",
                "silk/LPC_analysis_filter.c",
                "silk/LPC_inv_pred_gain.c",
                "silk/table_LSF_cos.c",
                "silk/NLSF2A.c",
                "silk/NLSF_stabilize.c",
                "silk/NLSF_VQ_weights_laroia.c",
                "silk/pitch_est_tables.c",
                "silk/resampler.c",
                "silk/resampler_down2_3.c",
                "silk/resampler_down2.c",
                "silk/resampler_private_AR2.c",
                "silk/resampler_private_down_FIR.c",
                "silk/resampler_private_IIR_FIR.c",
                "silk/resampler_private_up2_HQ.c",
                "silk/resampler_rom.c",
                "silk/sigm_Q15.c",
                "silk/sort.c",
                "silk/sum_sqr_shift.c",
                "silk/stereo_decode_pred.c",
                "silk/stereo_encode_pred.c",
                "silk/stereo_find_predictor.c",
                "silk/stereo_quant_pred.c",
                "silk/LPC_fit.c",
                "silk/float/apply_sine_window_FLP.c",
                "silk/float/corrMatrix_FLP.c",
                "silk/float/encode_frame_FLP.c",
                "silk/float/find_LPC_FLP.c",
                "silk/float/find_LTP_FLP.c",
                "silk/float/find_pitch_lags_FLP.c",
                "silk/float/find_pred_coefs_FLP.c",
                "silk/float/LPC_analysis_filter_FLP.c",
                "silk/float/LTP_analysis_filter_FLP.c",
                "silk/float/LTP_scale_ctrl_FLP.c",
                "silk/float/noise_shape_analysis_FLP.c",
                "silk/float/process_gains_FLP.c",
                "silk/float/regularize_correlations_FLP.c",
                "silk/float/residual_energy_FLP.c",
                "silk/float/warped_autocorrelation_FLP.c",
                "silk/float/wrappers_FLP.c",
                "silk/float/autocorrelation_FLP.c",
                "silk/float/burg_modified_FLP.c",
                "silk/float/bwexpander_FLP.c",
                "silk/float/energy_FLP.c",
                "silk/float/inner_product_FLP.c",
                "silk/float/k2a_FLP.c",
                "silk/float/LPC_inv_pred_gain_FLP.c",
                "silk/float/pitch_analysis_core_FLP.c",
                "silk/float/scale_copy_vector_FLP.c",
                "silk/float/scale_vector_FLP.c",
                "silk/float/schur_FLP.c",
                "silk/float/sort_FLP.c"
            ],
            publicHeadersPath: "openlola_bridge/include",
            cSettings: [
                .define("OPUS_BUILD"),
                .define("VAR_ARRAYS"),
                .define("HAVE_LRINTF"),
                .headerSearchPath("include"),
                .headerSearchPath("celt"),
                .headerSearchPath("silk"),
                .headerSearchPath("silk/float"),
                .headerSearchPath("src")
            ]
        ),
        .executableTarget(
            name: "open-lola",
            dependencies: ["OpenLolaCore"],
            exclude: ["Info.plist", "open-lola.entitlements"],
            linkerSettings: executableInfoPlistLinkerSettings("Sources/open-lola/Info.plist")
        ),
        .executableTarget(
            name: "open-lola-app",
            dependencies: ["OpenLolaAppSupport"],
            path: "Sources/open-lola-app-main",
            linkerSettings: executableInfoPlistLinkerSettings("Sources/open-lola-app/Info.plist")
        ),
        .testTarget(
            name: "OpenLolaCoreTests",
            dependencies: ["OpenLolaCore", "OpenLolaContracts", "OpenLolaAppSupport"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
