# -----------------------------------------------------------------------------
# JELLYFIN-CONFIG MODULE - VARIABLES
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# PROVIDER CONNECTION
# -----------------------------------------------------------------------------

variable "jellyfin_endpoint" {
  description = "Jellyfin server base URL (e.g. http://host:8096); sourced from TF_VAR_jellyfin_endpoint via the env_helper."
  type        = string
}

variable "jellyfin_api_key" {
  description = "Jellyfin API key; sourced from TF_VAR_jellyfin_api_key via the env_helper."
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# SINGLETON CONFIGURATIONS
# -----------------------------------------------------------------------------
# --- Every attribute is optional; the provider treats an unset one as computed
#     and leaves the server's current value alone. null for the whole object
#     leaves the singleton unmanaged. The concrete values live in the
#     env_helper, so the full surface is declared here whether used or not. ---

variable "encoding_configuration" {
  description = "Encoding/transcoding settings for jellyfin_encoding_configuration. null = unmanaged."
  default     = null
  type = object({
    allow_av1_encoding                                                = optional(bool)
    allow_hevc_encoding                                               = optional(bool)
    allow_on_demand_metadata_based_keyframe_extraction_for_extensions = optional(list(string))
    deinterlace_double_rate                                           = optional(bool)
    deinterlace_method                                                = optional(string)
    down_mix_audio_boost                                              = optional(number)
    down_mix_stereo_algorithm                                         = optional(string)
    enable_audio_vbr                                                  = optional(bool)
    enable_decoding_color_depth10_hevc                                = optional(bool)
    enable_decoding_color_depth10_hevc_rext                           = optional(bool)
    enable_decoding_color_depth10_vp9                                 = optional(bool)
    enable_decoding_color_depth12_hevc_rext                           = optional(bool)
    enable_enhanced_nvdec_decoder                                     = optional(bool)
    enable_fallback_font                                              = optional(bool)
    enable_hardware_encoding                                          = optional(bool)
    enable_intel_low_power_h264_hw_encoder                            = optional(bool)
    enable_intel_low_power_hevc_hw_encoder                            = optional(bool)
    enable_segment_deletion                                           = optional(bool)
    enable_subtitle_extraction                                        = optional(bool)
    enable_throttling                                                 = optional(bool)
    enable_tonemapping                                                = optional(bool)
    enable_video_toolbox_tonemapping                                  = optional(bool)
    enable_vpp_tonemapping                                            = optional(bool)
    encoder_app_path                                                  = optional(string)
    encoder_app_path_display                                          = optional(string)
    encoder_preset                                                    = optional(string)
    encoding_thread_count                                             = optional(number)
    fallback_font_path                                                = optional(string)
    h264_crf                                                          = optional(number)
    h265_crf                                                          = optional(number)
    hardware_acceleration_type                                        = optional(string)
    hardware_decoding_codecs                                          = optional(list(string))
    max_muxing_queue_size                                             = optional(number)
    prefer_system_native_hw_decoder                                   = optional(bool)
    qsv_device                                                        = optional(string)
    segment_keep_seconds                                              = optional(number)
    throttle_delay_seconds                                            = optional(number)
    tonemapping_algorithm                                             = optional(string)
    tonemapping_desat                                                 = optional(number)
    tonemapping_mode                                                  = optional(string)
    tonemapping_param                                                 = optional(number)
    tonemapping_peak                                                  = optional(number)
    tonemapping_range                                                 = optional(string)
    transcoding_temp_path                                             = optional(string)
    vaapi_device                                                      = optional(string)
    vpp_tonemapping_brightness                                        = optional(number)
    vpp_tonemapping_contrast                                          = optional(number)
  })
}

variable "livetv_configuration" {
  description = "Live TV settings (tuner hosts + listing providers) for jellyfin_livetv_configuration. null = unmanaged."
  default     = null
  type = object({
    enable_original_audio_with_encoded_recordings = optional(bool)
    enable_recording_subfolders                   = optional(bool)
    guide_days                                    = optional(number)
    media_locations_created                       = optional(list(string))
    movie_recording_path                          = optional(string)
    post_padding_seconds                          = optional(number)
    pre_padding_seconds                           = optional(number)
    recording_path                                = optional(string)
    recording_post_processor                      = optional(string)
    recording_post_processor_arguments            = optional(string)
    save_recording_images                         = optional(bool)
    save_recording_nfo                            = optional(bool)
    series_recording_path                         = optional(string)

    tuner_hosts = optional(list(object({
      allow_fmp4_transcoding_container = optional(bool)
      allow_hw_transcoding             = optional(bool)
      allow_stream_sharing             = optional(bool)
      device_id                        = optional(string)
      enable_stream_looping            = optional(bool)
      fallback_max_streaming_bitrate   = optional(number)
      friendly_name                    = optional(string)
      id                               = optional(string)
      ignore_dts                       = optional(bool)
      import_favorites_only            = optional(bool)
      read_at_native_framerate         = optional(bool)
      source                           = optional(string)
      tuner_count                      = optional(number)
      type                             = optional(string)
      url                              = optional(string)
      user_agent                       = optional(string)
    })))

    listing_providers = optional(list(object({
      channel_mappings = optional(list(object({
        name  = optional(string)
        value = optional(string)
      })))
      country            = optional(string)
      enable_all_tuners  = optional(bool)
      enabled_tuners     = optional(list(string))
      id                 = optional(string)
      kids_categories    = optional(list(string))
      listings_id        = optional(string)
      movie_categories   = optional(list(string))
      movie_prefix       = optional(string)
      news_categories    = optional(list(string))
      password           = optional(string)
      path               = optional(string)
      preferred_language = optional(string)
      sports_categories  = optional(list(string))
      type               = optional(string)
      user_agent         = optional(string)
      username           = optional(string)
      zip_code           = optional(string)
    })))
  })
}

variable "system_configuration" {
  description = "System settings for jellyfin_system_configuration. null = unmanaged."
  default     = null
  type = object({
    activity_log_retention_days             = optional(number)
    allow_client_log_upload                 = optional(bool)
    cache_path                              = optional(string)
    cache_size                              = optional(number)
    cast_receiver_applications              = optional(list(object({ id = optional(string), name = optional(string) })))
    chapter_image_resolution                = optional(string)
    codecs_used                             = optional(list(string))
    content_types                           = optional(list(object({ name = optional(string), value = optional(string) })))
    cors_hosts                              = optional(list(string))
    disable_live_tv_channel_user_data_name  = optional(bool)
    display_specials_within_seasons         = optional(bool)
    dummy_chapter_duration                  = optional(number)
    enable_case_sensitive_item_ids          = optional(bool)
    enable_external_content_in_suggestions  = optional(bool)
    enable_folder_view                      = optional(bool)
    enable_grouping_movies_into_collections = optional(bool)
    enable_grouping_shows_into_collections  = optional(bool)
    enable_legacy_authorization             = optional(bool)
    enable_metrics                          = optional(bool)
    enable_normalized_item_by_name_ids      = optional(bool)
    enable_slow_response_warning            = optional(bool)
    image_extraction_timeout_ms             = optional(number)
    image_saving_convention                 = optional(string)
    inactive_session_threshold              = optional(number)
    is_port_authorized                      = optional(bool)
    library_metadata_refresh_concurrency    = optional(number)
    library_monitor_delay                   = optional(number)
    library_scan_fanout_concurrency         = optional(number)
    library_update_duration                 = optional(number)
    log_file_retention_days                 = optional(number)
    max_audiobook_resume                    = optional(number)
    max_resume_pct                          = optional(number)
    metadata_country_code                   = optional(string)
    metadata_path                           = optional(string)
    metadata_options = optional(list(object({
      disabled_image_fetchers     = optional(list(string))
      disabled_metadata_fetchers  = optional(list(string))
      disabled_metadata_savers    = optional(list(string))
      image_fetcher_order         = optional(list(string))
      item_type                   = optional(string)
      local_metadata_reader_order = optional(list(string))
      metadata_fetcher_order      = optional(list(string))
    })))
    path_substitutions = optional(list(object({
      from = optional(string)
      to   = optional(string)
    })))
    trickplay_options = optional(object({
      enable_hw_acceleration           = optional(bool)
      enable_hw_encoding               = optional(bool)
      enable_key_frame_only_extraction = optional(bool)
      interval                         = optional(number)
      jpeg_quality                     = optional(number)
      process_priority                 = optional(string)
      process_threads                  = optional(number)
      qscale                           = optional(number)
      scan_behavior                    = optional(string)
      tile_height                      = optional(number)
      tile_width                       = optional(number)
      width_resolutions                = optional(list(number))
    }))
    min_audiobook_resume                 = optional(number)
    min_resume_duration_seconds          = optional(number)
    min_resume_pct                       = optional(number)
    parallel_image_encoding_limit        = optional(number)
    preferred_metadata_language          = optional(string)
    quick_connect_available              = optional(bool)
    remote_client_bitrate_limit          = optional(number)
    save_metadata_hidden                 = optional(bool)
    server_name                          = optional(string)
    skip_deserialization_for_basic_types = optional(bool)
    slow_response_threshold_ms           = optional(number)
    sort_remove_characters               = optional(list(string))
    sort_remove_words                    = optional(list(string))
    sort_replace_characters              = optional(list(string))
    ui_culture                           = optional(string)
  })
}

# -----------------------------------------------------------------------------
# SCHEDULED TASKS
# -----------------------------------------------------------------------------

variable "scheduled_tasks" {
  description = "Map of Jellyfin scheduled tasks to manage; map key is the Terraform state key."
  default     = {}
  type = map(object({
    task_id = string
    triggers = list(object({
      day_of_week       = optional(string)
      interval_ticks    = optional(number)
      max_runtime_ticks = optional(number)
      time_of_day_ticks = optional(number)
      type              = optional(string)
    }))
  }))
}
