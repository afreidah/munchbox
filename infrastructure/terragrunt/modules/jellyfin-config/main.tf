# -----------------------------------------------------------------------------
# JELLYFIN-CONFIG MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Manages a self-hosted Jellyfin server's configuration: the singleton encoding,
# Live TV, and system config objects, plus scheduled-task triggers. Every
# attribute is optional and computed, so an unset one keeps whatever the server
# already has; the concrete values live in the env_helper.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# ENCODING CONFIGURATION (singleton)
# -----------------------------------------------------------------------------

resource "jellyfin_encoding_configuration" "this" {
  count = var.encoding_configuration == null ? 0 : 1

  allow_av1_encoding                                                = var.encoding_configuration.allow_av1_encoding
  allow_hevc_encoding                                               = var.encoding_configuration.allow_hevc_encoding
  allow_on_demand_metadata_based_keyframe_extraction_for_extensions = var.encoding_configuration.allow_on_demand_metadata_based_keyframe_extraction_for_extensions
  deinterlace_double_rate                                           = var.encoding_configuration.deinterlace_double_rate
  deinterlace_method                                                = var.encoding_configuration.deinterlace_method
  down_mix_audio_boost                                              = var.encoding_configuration.down_mix_audio_boost
  down_mix_stereo_algorithm                                         = var.encoding_configuration.down_mix_stereo_algorithm
  enable_audio_vbr                                                  = var.encoding_configuration.enable_audio_vbr
  enable_decoding_color_depth10_hevc                                = var.encoding_configuration.enable_decoding_color_depth10_hevc
  enable_decoding_color_depth10_hevc_rext                           = var.encoding_configuration.enable_decoding_color_depth10_hevc_rext
  enable_decoding_color_depth10_vp9                                 = var.encoding_configuration.enable_decoding_color_depth10_vp9
  enable_decoding_color_depth12_hevc_rext                           = var.encoding_configuration.enable_decoding_color_depth12_hevc_rext
  enable_enhanced_nvdec_decoder                                     = var.encoding_configuration.enable_enhanced_nvdec_decoder
  enable_fallback_font                                              = var.encoding_configuration.enable_fallback_font
  enable_hardware_encoding                                          = var.encoding_configuration.enable_hardware_encoding
  enable_intel_low_power_h264_hw_encoder                            = var.encoding_configuration.enable_intel_low_power_h264_hw_encoder
  enable_intel_low_power_hevc_hw_encoder                            = var.encoding_configuration.enable_intel_low_power_hevc_hw_encoder
  enable_segment_deletion                                           = var.encoding_configuration.enable_segment_deletion
  enable_subtitle_extraction                                        = var.encoding_configuration.enable_subtitle_extraction
  enable_throttling                                                 = var.encoding_configuration.enable_throttling
  enable_tonemapping                                                = var.encoding_configuration.enable_tonemapping
  enable_video_toolbox_tonemapping                                  = var.encoding_configuration.enable_video_toolbox_tonemapping
  enable_vpp_tonemapping                                            = var.encoding_configuration.enable_vpp_tonemapping
  encoder_app_path                                                  = var.encoding_configuration.encoder_app_path
  encoder_app_path_display                                          = var.encoding_configuration.encoder_app_path_display
  encoder_preset                                                    = var.encoding_configuration.encoder_preset
  encoding_thread_count                                             = var.encoding_configuration.encoding_thread_count
  fallback_font_path                                                = var.encoding_configuration.fallback_font_path
  h264_crf                                                          = var.encoding_configuration.h264_crf
  h265_crf                                                          = var.encoding_configuration.h265_crf
  hardware_acceleration_type                                        = var.encoding_configuration.hardware_acceleration_type
  hardware_decoding_codecs                                          = var.encoding_configuration.hardware_decoding_codecs
  max_muxing_queue_size                                             = var.encoding_configuration.max_muxing_queue_size
  prefer_system_native_hw_decoder                                   = var.encoding_configuration.prefer_system_native_hw_decoder
  qsv_device                                                        = var.encoding_configuration.qsv_device
  segment_keep_seconds                                              = var.encoding_configuration.segment_keep_seconds
  throttle_delay_seconds                                            = var.encoding_configuration.throttle_delay_seconds
  tonemapping_algorithm                                             = var.encoding_configuration.tonemapping_algorithm
  tonemapping_desat                                                 = var.encoding_configuration.tonemapping_desat
  tonemapping_mode                                                  = var.encoding_configuration.tonemapping_mode
  tonemapping_param                                                 = var.encoding_configuration.tonemapping_param
  tonemapping_peak                                                  = var.encoding_configuration.tonemapping_peak
  tonemapping_range                                                 = var.encoding_configuration.tonemapping_range
  transcoding_temp_path                                             = var.encoding_configuration.transcoding_temp_path
  vaapi_device                                                      = var.encoding_configuration.vaapi_device
  vpp_tonemapping_brightness                                        = var.encoding_configuration.vpp_tonemapping_brightness
  vpp_tonemapping_contrast                                          = var.encoding_configuration.vpp_tonemapping_contrast
}

# -----------------------------------------------------------------------------
# LIVE TV CONFIGURATION (singleton)
# -----------------------------------------------------------------------------

resource "jellyfin_livetv_configuration" "this" {
  count = var.livetv_configuration == null ? 0 : 1

  enable_original_audio_with_encoded_recordings = var.livetv_configuration.enable_original_audio_with_encoded_recordings
  enable_recording_subfolders                   = var.livetv_configuration.enable_recording_subfolders
  guide_days                                    = var.livetv_configuration.guide_days
  listing_providers                             = var.livetv_configuration.listing_providers
  media_locations_created                       = var.livetv_configuration.media_locations_created
  movie_recording_path                          = var.livetv_configuration.movie_recording_path
  post_padding_seconds                          = var.livetv_configuration.post_padding_seconds
  pre_padding_seconds                           = var.livetv_configuration.pre_padding_seconds
  recording_path                                = var.livetv_configuration.recording_path
  recording_post_processor                      = var.livetv_configuration.recording_post_processor
  recording_post_processor_arguments            = var.livetv_configuration.recording_post_processor_arguments
  save_recording_images                         = var.livetv_configuration.save_recording_images
  save_recording_nfo                            = var.livetv_configuration.save_recording_nfo
  series_recording_path                         = var.livetv_configuration.series_recording_path
  tuner_hosts                                   = var.livetv_configuration.tuner_hosts
}

# -----------------------------------------------------------------------------
# SYSTEM CONFIGURATION (singleton)
# -----------------------------------------------------------------------------

resource "jellyfin_system_configuration" "this" {
  count = var.system_configuration == null ? 0 : 1

  activity_log_retention_days             = var.system_configuration.activity_log_retention_days
  allow_client_log_upload                 = var.system_configuration.allow_client_log_upload
  cache_path                              = var.system_configuration.cache_path
  cache_size                              = var.system_configuration.cache_size
  cast_receiver_applications              = var.system_configuration.cast_receiver_applications
  chapter_image_resolution                = var.system_configuration.chapter_image_resolution
  codecs_used                             = var.system_configuration.codecs_used
  content_types                           = var.system_configuration.content_types
  cors_hosts                              = var.system_configuration.cors_hosts
  disable_live_tv_channel_user_data_name  = var.system_configuration.disable_live_tv_channel_user_data_name
  display_specials_within_seasons         = var.system_configuration.display_specials_within_seasons
  dummy_chapter_duration                  = var.system_configuration.dummy_chapter_duration
  enable_case_sensitive_item_ids          = var.system_configuration.enable_case_sensitive_item_ids
  enable_external_content_in_suggestions  = var.system_configuration.enable_external_content_in_suggestions
  enable_folder_view                      = var.system_configuration.enable_folder_view
  enable_grouping_movies_into_collections = var.system_configuration.enable_grouping_movies_into_collections
  enable_grouping_shows_into_collections  = var.system_configuration.enable_grouping_shows_into_collections
  enable_legacy_authorization             = var.system_configuration.enable_legacy_authorization
  enable_metrics                          = var.system_configuration.enable_metrics
  enable_normalized_item_by_name_ids      = var.system_configuration.enable_normalized_item_by_name_ids
  enable_slow_response_warning            = var.system_configuration.enable_slow_response_warning
  image_extraction_timeout_ms             = var.system_configuration.image_extraction_timeout_ms
  image_saving_convention                 = var.system_configuration.image_saving_convention
  inactive_session_threshold              = var.system_configuration.inactive_session_threshold
  is_port_authorized                      = var.system_configuration.is_port_authorized
  library_metadata_refresh_concurrency    = var.system_configuration.library_metadata_refresh_concurrency
  library_monitor_delay                   = var.system_configuration.library_monitor_delay
  library_scan_fanout_concurrency         = var.system_configuration.library_scan_fanout_concurrency
  library_update_duration                 = var.system_configuration.library_update_duration
  log_file_retention_days                 = var.system_configuration.log_file_retention_days
  max_audiobook_resume                    = var.system_configuration.max_audiobook_resume
  max_resume_pct                          = var.system_configuration.max_resume_pct
  metadata_country_code                   = var.system_configuration.metadata_country_code
  metadata_options                        = var.system_configuration.metadata_options
  metadata_path                           = var.system_configuration.metadata_path
  min_audiobook_resume                    = var.system_configuration.min_audiobook_resume
  min_resume_duration_seconds             = var.system_configuration.min_resume_duration_seconds
  min_resume_pct                          = var.system_configuration.min_resume_pct
  parallel_image_encoding_limit           = var.system_configuration.parallel_image_encoding_limit
  path_substitutions                      = var.system_configuration.path_substitutions
  preferred_metadata_language             = var.system_configuration.preferred_metadata_language
  quick_connect_available                 = var.system_configuration.quick_connect_available
  remote_client_bitrate_limit             = var.system_configuration.remote_client_bitrate_limit
  save_metadata_hidden                    = var.system_configuration.save_metadata_hidden
  server_name                             = var.system_configuration.server_name
  skip_deserialization_for_basic_types    = var.system_configuration.skip_deserialization_for_basic_types
  slow_response_threshold_ms              = var.system_configuration.slow_response_threshold_ms
  sort_remove_characters                  = var.system_configuration.sort_remove_characters
  sort_remove_words                       = var.system_configuration.sort_remove_words
  sort_replace_characters                 = var.system_configuration.sort_replace_characters
  trickplay_options                       = var.system_configuration.trickplay_options
  ui_culture                              = var.system_configuration.ui_culture
}

# -----------------------------------------------------------------------------
# SCHEDULED TASKS
# -----------------------------------------------------------------------------

resource "jellyfin_scheduled_task" "this" {
  for_each = var.scheduled_tasks

  task_id  = each.value.task_id
  triggers = each.value.triggers
}
