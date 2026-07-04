# -----------------------------------------------------------------------------
# JELLYFIN-CONFIG ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the jellyfin-config module. The provider endpoint + api_key
# come from Vault (secret/jellyfin) via TF_VAR_* exported by munchbox-env.sh;
# the static settings live here and are json-encoded into the module inputs.
# To codify new settings: pull current config from the jellyfin API, paste the
# settings object below, then `terragrunt import` the singleton before applying.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//jellyfin-config"
}

locals {
  encoding_configuration = {
    EncodingThreadCount                                       = -1
    EnableFallbackFont                                        = false
    EnableAudioVbr                                            = false
    DownMixAudioBoost                                         = 2
    DownMixStereoAlgorithm                                    = "None"
    MaxMuxingQueueSize                                        = 2048
    EnableThrottling                                          = true
    ThrottleDelaySeconds                                      = 180
    EnableSegmentDeletion                                     = true
    SegmentKeepSeconds                                        = 720
    HardwareAccelerationType                                  = "nvenc"
    EncoderAppPathDisplay                                     = "/usr/lib/jellyfin-ffmpeg/ffmpeg"
    VaapiDevice                                               = "/dev/dri/renderD128"
    QsvDevice                                                 = ""
    EnableTonemapping                                         = false
    EnableVppTonemapping                                      = false
    EnableVideoToolboxTonemapping                             = false
    TonemappingAlgorithm                                      = "bt2390"
    TonemappingMode                                           = "auto"
    TonemappingRange                                          = "auto"
    TonemappingDesat                                          = 0
    TonemappingPeak                                           = 100
    TonemappingParam                                          = 0
    VppTonemappingBrightness                                  = 16
    VppTonemappingContrast                                    = 1
    H264Crf                                                   = 23
    H265Crf                                                   = 28
    DeinterlaceDoubleRate                                     = false
    DeinterlaceMethod                                         = "yadif"
    EnableDecodingColorDepth10Hevc                            = true
    EnableDecodingColorDepth10Vp9                             = true
    EnableDecodingColorDepth10HevcRext                        = false
    EnableDecodingColorDepth12HevcRext                        = false
    EnableEnhancedNvdecDecoder                                = true
    PreferSystemNativeHwDecoder                               = true
    EnableIntelLowPowerH264HwEncoder                          = false
    EnableIntelLowPowerHevcHwEncoder                          = false
    EnableHardwareEncoding                                    = true
    AllowHevcEncoding                                         = true
    AllowAv1Encoding                                          = true
    EnableSubtitleExtraction                                  = true
    HardwareDecodingCodecs                                    = ["h264", "vc1", "hevc", "av1"]
    AllowOnDemandMetadataBasedKeyframeExtractionForExtensions = ["mkv"]
  }

  livetv_configuration = {
    EnableRecordingSubfolders                = false
    EnableOriginalAudioWithEncodedRecordings = false
    TunerHosts = [
      {
        Id                  = "1bdb95cd37bb4c4f879ff486cf3549d9"
        Url                 = "http://ersatztv.service.consul:8409/iptv/channels.m3u"
        Type                = "m3u"
        ImportFavoritesOnly = false
        AllowHWTranscoding  = false
        # true -> live-TV transcodes use the segmented fMP4/HLS container instead of a
        # single continuous .ts, so EnableSegmentDeletion/SegmentKeepSeconds (720s) below
        # actually bound them. A single-file .ts transcode is unbounded and once grew to
        # 63G, filling nomad-client-04's root disk.
        AllowFmp4TranscodingContainer = true
        AllowStreamSharing            = true
        FallbackMaxStreamingBitrate   = 30000000
        EnableStreamLooping           = false
        TunerCount                    = 0
        IgnoreDts                     = true
        ReadAtNativeFramerate         = true
      },
    ]
    ListingProviders = [
      {
        Id               = "2dd2e37d7d82444cbb457977c197277f"
        Type             = "xmltv"
        Path             = "http://ersatztv.service.consul:8409/iptv/xmltv.xml"
        EnabledTuners    = []
        EnableAllTuners  = true
        NewsCategories   = ["news", "journalism", "documentary", "current affairs"]
        SportsCategories = ["sports", "basketball", "baseball", "football"]
        KidsCategories   = ["kids", "family", "children", "childrens", "disney"]
        MovieCategories  = ["movie"]
        ChannelMappings  = []
      },
    ]
    PrePaddingSeconds               = 0
    PostPaddingSeconds              = 0
    MediaLocationsCreated           = []
    RecordingPostProcessorArguments = "\"{path}\""
    SaveRecordingNFO                = true
    SaveRecordingImages             = true
  }

  system_configuration = null

  scheduled_tasks = {
    "guide-refresh" = {
      task_id  = "bea9b218c97bbf98c5dc1303bdb9a0ca"
      triggers = [{ Type = "IntervalTrigger", IntervalTicks = 72000000000 }]
    }
  }
}

inputs = {
  # --- take the URL token only; the Vault value may carry a trailing note ---
  jellyfin_endpoint = trimspace(split(" ", get_env("TF_VAR_jellyfin_endpoint", ""))[0])
  jellyfin_api_key  = get_env("TF_VAR_jellyfin_api_key", "")

  # --- json-encode each settings object here; null passes through untouched ---
  encoding_configuration_json = local.encoding_configuration == null ? null : jsonencode(local.encoding_configuration)
  livetv_configuration_json   = local.livetv_configuration == null ? null : jsonencode(local.livetv_configuration)
  system_configuration_json   = local.system_configuration == null ? null : jsonencode(local.system_configuration)

  scheduled_tasks = {
    for k, t in local.scheduled_tasks :
    k => { task_id = t.task_id, triggers_json = jsonencode(t.triggers) }
  }
}
