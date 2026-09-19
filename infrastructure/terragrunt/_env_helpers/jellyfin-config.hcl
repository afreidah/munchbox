# -----------------------------------------------------------------------------
# JELLYFIN-CONFIG ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the jellyfin-config module. The provider endpoint + api_key
# come from Vault (secret/jellyfin) via TF_VAR_* exported by munchbox-env.sh;
# the static settings live here. Attribute names are the provider's, which are
# snake_case renderings of the Jellyfin API's PascalCase keys. An attribute
# left out keeps whatever the server already has.
# To codify new settings: pull current config from the jellyfin API, translate
# the keys, then `terragrunt import` the singleton before applying.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//jellyfin-config"
}

locals {
  encoding_configuration = {
    encoding_thread_count                   = -1
    enable_fallback_font                    = false
    enable_audio_vbr                        = false
    down_mix_audio_boost                    = 2
    down_mix_stereo_algorithm               = "None"
    max_muxing_queue_size                   = 2048
    enable_throttling                       = true
    throttle_delay_seconds                  = 180
    enable_segment_deletion                 = true
    segment_keep_seconds                    = 720
    hardware_acceleration_type              = "nvenc"
    encoder_app_path_display                = "/usr/lib/jellyfin-ffmpeg/ffmpeg"
    vaapi_device                            = "/dev/dri/renderD128"
    qsv_device                              = ""
    enable_tonemapping                      = false
    enable_vpp_tonemapping                  = false
    enable_video_toolbox_tonemapping        = false
    tonemapping_algorithm                   = "bt2390"
    tonemapping_mode                        = "auto"
    tonemapping_range                       = "auto"
    tonemapping_desat                       = 0
    tonemapping_peak                        = 100
    tonemapping_param                       = 0
    vpp_tonemapping_brightness              = 16
    vpp_tonemapping_contrast                = 1
    h264_crf                                = 23
    h265_crf                                = 28
    deinterlace_double_rate                 = false
    deinterlace_method                      = "yadif"
    enable_decoding_color_depth10_hevc      = true
    enable_decoding_color_depth10_vp9       = true
    enable_decoding_color_depth10_hevc_rext = false
    enable_decoding_color_depth12_hevc_rext = false
    enable_enhanced_nvdec_decoder           = true
    prefer_system_native_hw_decoder         = true
    enable_intel_low_power_h264_hw_encoder  = false
    enable_intel_low_power_hevc_hw_encoder  = false
    enable_hardware_encoding                = true
    allow_hevc_encoding                     = true
    # --- the A1000 is Ampere: it decodes AV1 but has no AV1 encoder, so asking
    #     for one only buys a silent fallback to software ---
    allow_av1_encoding         = false
    enable_subtitle_extraction = true
    hardware_decoding_codecs   = ["h264", "vc1", "hevc", "av1"]

    allow_on_demand_metadata_based_keyframe_extraction_for_extensions = ["mkv"]
  }

  livetv_configuration = {
    enable_recording_subfolders                   = false
    enable_original_audio_with_encoded_recordings = false

    tuner_hosts = [
      {
        id                    = "1bdb95cd37bb4c4f879ff486cf3549d9"
        url                   = "http://ersatztv.service.consul:8409/iptv/channels.m3u"
        type                  = "m3u"
        import_favorites_only = false
        allow_hw_transcoding  = false
        # true -> live-TV transcodes use the segmented fMP4/HLS container instead of a
        # single continuous .ts, so enable_segment_deletion/segment_keep_seconds (720s)
        # above actually bound them. A single-file .ts transcode is unbounded and once
        # grew to 63G, filling nomad-client-04's root disk.
        allow_fmp4_transcoding_container = true
        allow_stream_sharing             = true
        fallback_max_streaming_bitrate   = 30000000
        enable_stream_looping            = false
        tuner_count                      = 0
        ignore_dts                       = true
        read_at_native_framerate         = true
      },
    ]

    listing_providers = [
      {
        id                = "2dd2e37d7d82444cbb457977c197277f"
        type              = "xmltv"
        path              = "http://ersatztv.service.consul:8409/iptv/xmltv.xml"
        enabled_tuners    = []
        enable_all_tuners = true
        news_categories   = ["news", "journalism", "documentary", "current affairs"]
        sports_categories = ["sports", "basketball", "baseball", "football"]
        kids_categories   = ["kids", "family", "children", "childrens", "disney"]
        movie_categories  = ["movie"]
        channel_mappings  = []
      },
    ]

    pre_padding_seconds                = 0
    post_padding_seconds               = 0
    media_locations_created            = []
    recording_post_processor_arguments = "\"{path}\""
    save_recording_nfo                 = true
    save_recording_images              = true
  }

  system_configuration = null

  scheduled_tasks = {
    "guide-refresh" = {
      task_id  = "bea9b218c97bbf98c5dc1303bdb9a0ca"
      triggers = [{ type = "IntervalTrigger", interval_ticks = 72000000000 }]
    }
  }
}

inputs = {
  # --- take the URL token only; the Vault value may carry a trailing note ---
  jellyfin_endpoint = trimspace(split(" ", get_env("TF_VAR_jellyfin_endpoint", ""))[0])
  jellyfin_api_key  = get_env("TF_VAR_jellyfin_api_key", "")

  encoding_configuration = local.encoding_configuration
  livetv_configuration   = local.livetv_configuration
  system_configuration   = local.system_configuration
  scheduled_tasks        = local.scheduled_tasks
}
