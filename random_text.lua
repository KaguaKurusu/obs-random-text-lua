obs = obslua

-- Settings start

-- Sequential numbers.
SEQ_NUM = {
	min = -10000,
	max = 10000,
	step = 1,
}

BLANK_TIME = {
	min = 100,
	max = 500,
	step = 50
}

TIME_TO_DISPLAY = {
	min = 1,
	max = 5,
	step = 1
}

ROLL_DELAY = {
	min = 1,
	max = 200,
	step = 2
}

DECELERATION = {
	min = 0,
	max = 1000,
	step = 50
}

-- Settings end

Data = {
	_props = nil,
	_settings = nil,

	lines = {},
	source_name = "",
	blank_time = 250,

	-- Genarate Consecutive numbers
	is_seq_num_mode = false,
	seq_num_start = 1,
	seq_num_stop = 4,

	-- Animation
	with_animation = false,
	time_to_display = 2,
	roll_delay = 42,
	deceleration = 50,
	with_bgm = false,
	bgm_path = "",
	bgm_source = nil,
	bgm_index = 62,

	-- Play Sound
	play_sound = false,
	sound_path = "",
	media_source = nil,
	output_index = 63
}

Hotkey = {
	new = function(callback, obs_settings, _id, description)
		local obj = {}

		obj.obs_data = obs_settings
		obj.hotkey_id = obs.OBS_INVALID_HOTKEY_ID
		obj.hotkey_saved_key = nil
		obj.callback = callback
		obj._id = _id
		obj.description = description

		obj.register_hotkey = function(self)
			self.hotkey_id = obs.obs_hotkey_register_frontend("htk_id_" .. self._id, self.description, self.callback)
			obs.obs_hotkey_load(self.hotkey_id, self.hotkey_saved_key)
		end

		obj.load_hotkey = function(self)
			self.hotkey_saved_key = obs.obs_data_get_array(self.obs_data, "htk_id_" .. self._id)
			obs.obs_data_array_release(self.hotkey_saved_key)
		end
	
		obj.save_hotkey = function(self)
			self.hotkey_saved_key = obs.obs_hotkey_save(self.hotkey_id)
			obs.obs_data_set_array(self.obs_data, "htk_id_" .. self._id, self.hotkey_saved_key)
			obs.obs_data_array_release(self.hotkey_saved_key)
		end

		obj.load_hotkey(obj)
		obj.register_hotkey(obj)
		obj.save_hotkey(obj)

		return obj
	end
}

hotkey_get_random = {}

function update_text()
	local source = obs.obs_get_source_by_name(Data.source_name)

	if source ~= nil then
		local settings = obs.obs_data_create()

		-- Update source
		local text = ""
		if #Data.lines > 0 then
			math.randomseed(obs.os_gettime_ns())
			local index = math.random(#Data.lines)

			if Data.with_animation then
				animate_selection(settings, source, Data.lines)
			else
				obs.obs_data_set_string(settings, "text", text)
				obs.obs_source_update(source, settings)
				obs.os_sleep_ms(Data.blank_time)
			end

			if Data.play_sound then
				play_sound()
			end

			text = Data.lines[index]
			obs.obs_data_set_string(settings, "text", text)
			obs.obs_source_update(source, settings)
			obs.obs_data_release(settings)
			obs.obs_source_release(source)
		end
	end
end

function animate_selection(settings, source, lines)
	local time_limit = Data.time_to_display
	local sleep_time = Data.roll_delay / 1000
	local deceleration_default = Data.deceleration / 1000
	local lines_count = #lines
	local deceleration = 0
	local speed_modification = 1

	if Data.with_bgm then
		start_bgm()
	end

	math.randomseed(obs.os_gettime_ns())
	while time_limit > 0 do
		local random_index = math.random(lines_count)
		obs.obs_data_set_string(settings, "text", lines[random_index])
		obs.obs_source_update(source, settings)

		local current_sleep_time = sleep_time * (speed_modification + deceleration)
		time_limit = time_limit - current_sleep_time

		deceleration = deceleration + deceleration_default

		obs.os_sleep_ms(current_sleep_time * 1000)
	end

	if Data.with_bgm then
		stop_bgm()
	end
end

function play_sound()
	if Data.media_source == nil then
		Data.media_source = obs.obs_source_create_private("ffmpeg_source", "Global Media Source", nil)
	end
	s = obs.obs_data_create()
	obs.obs_data_set_string(s, "local_file", Data.sound_path)
	obs.obs_source_update(Data.media_source, s)
	obs.obs_source_set_monitoring_type(Data.media_source, obs.OBS_MONITORING_TYPE_MONITOR_AND_OUTPUT)
	obs.obs_data_release(s)

	obs.obs_set_output_source(Data.output_index, Data.media_source)
end

function start_bgm()
	if Data.bgm_source == nil then
		Data.bgm_source = obs.obs_source_create_private("ffmpeg_source", "Global Media Source", nil)
	end
	s = obs.obs_data_create()
	obs.obs_data_set_string(s, "local_file", Data.bgm_path)
	obs.obs_data_set_bool(s, "looping", true)
	obs.obs_source_update(Data.bgm_source, s)
	obs.obs_source_set_monitoring_type(Data.bgm_source, obs.OBS_MONITORING_TYPE_MONITOR_AND_OUTPUT)
	obs.obs_data_release(s)

	obs.obs_set_output_source(Data.bgm_index, Data.bgm_source)
end

function stop_bgm()
	s = obs.obs_data_create()
	obs.obs_data_set_string(s, "local_file", "")
	obs.obs_source_update(Data.bgm_source, s)
	obs.obs_data_release(s)

	obs.obs_set_output_source(Data.bgm_index, Data.bgm_source)
end

function get_dir(path)
	if type(path) == "string" and path ~= "" then
		return string.match(path, ".*/");
	else
		return nul
	end
end

function on_get_random_click()
	update_text()
end

function on_get_random_hotkey_pressed(pressed)
	if pressed then
		update_text()
	end
end

function script_load(settings)
	hotkey_get_random = Hotkey.new(on_get_random_hotkey_pressed, settings, "get_random_text_lua", "抽選[Random text Lua]")
end

function script_save(settings)
	hotkey_get_random:save_hotkey()
end

function script_description()
	return "ランダムな文字列を表示するスクリプト。\
\
「連続する数値内から抽選する」が有効な場合、文字列リストは無視されます。\
「連続する数値内から抽選する」の開始値と終了値はどちらの方が小さくても問題ないです。\
指定可能範囲は" .. SEQ_NUM["min"] .. "から" .. SEQ_NUM["max"] .. "です。"
end

function script_update(settings)
	Data._settings = settings
	Data.source_name = obs.obs_data_get_string(settings, "source")
	Data.blank_time = obs.obs_data_get_int(settings, "blank_time")

	-- Sequential numbers mode
	Data.is_seq_num_mode = obs.obs_data_get_bool(settings, "is_seq_num_mode")
	Data.seq_num_start = obs.obs_data_get_int(settings, "seq_num_start")
	Data.seq_num_stop = obs.obs_data_get_int(settings, "seq_num_stop")

	--  Animation
	Data.with_animation = obs.obs_data_get_bool(settings, "with_animation")
	Data.deceleration = obs.obs_data_get_int(settings, "deceleration")
	Data.time_to_display = obs.obs_data_get_int(settings, "time_to_display")
	Data.roll_delay = obs.obs_data_get_int(settings, "roll_delay")
	Data.with_bgm = obs.obs_data_get_bool(settings, "with_bgm")
	Data.bgm_path = obs.obs_data_get_string(settings, "bgm_path")

	-- Sound
	Data.play_sound = obs.obs_data_get_bool(settings, "play_sound")
	Data.sound_path = obs.obs_data_get_string(settings, "sound_path")

	local lines = {}
	if Data.is_seq_num_mode then
		local step = 1
		if Data.seq_num_start > Data.seq_num_stop then
			step = -1
		end

		for i = Data.seq_num_start, Data.seq_num_stop, step do
			table.insert(lines, i)
		end
	else
		local string_list = obs.obs_data_get_string(settings, "string_list")

		for w in string_list:gmatch("[^\n]+") do
			if w:match("%g") ~= nil then
				local x = w:gsub("(.+)%s$", "%1")
				table.insert(lines, x)
			end
		end
	end

	Data.lines = lines
end

function script_defaults(settings)
	obs.obs_data_set_default_string(settings, "string_list", "1\n2\n3\n4\n")
	obs.obs_data_set_default_int(settings, "blank_time", Data.blank_time)

	-- Genarate consecutive number
	obs.obs_data_set_default_bool(settings, "is_seq_num_mode", Data.is_seq_num_mode)
	obs.obs_data_set_default_int(settings, "seq_num_start", Data.seq_num_start)
	obs.obs_data_set_default_int(settings, "seq_num_stop", Data.seq_num_stop)

	-- Animation
	obs.obs_data_set_default_bool(settings, "with_animation", Data.with_animation)
	obs.obs_data_set_default_int(settings, "roll_delay", Data.roll_delay)
	obs.obs_data_set_default_int(settings, "time_to_display", Data.time_to_display)
	obs.obs_data_set_default_int(settings, "deceleration", Data.deceleration)
	obs.obs_data_set_default_bool(settings, "with_bgm", Data.with_bgm)

	-- Sound
	obs.obs_data_set_default_bool(settings, "play_sound", Data.play_sound)
end

function script_properties()
	Data._props = obs.obs_properties_create()
	local props = Data._props
	local seq_num_props = obs.obs_properties_create()
	local animation_props = obs.obs_properties_create()
	local bgm_props = obs.obs_properties_create()
	local sound_props = obs.obs_properties_create()

	local p = obs.obs_properties_add_list(props, "source", "テキストソース", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()

	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_unversioned_id(source)

			if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(p, name, name)
			end
		end
	end

	obs.source_list_release(sources)

	obs.obs_properties_add_int(seq_num_props, "seq_num_start", "開始数値", SEQ_NUM["min"], SEQ_NUM["max"], SEQ_NUM["step"])
	obs.obs_properties_add_int(seq_num_props, "seq_num_stop", "終了数値", SEQ_NUM["min"], SEQ_NUM["max"], SEQ_NUM["step"])
	obs.obs_properties_add_group(props, "is_seq_num_mode", "連続する数値内から抽選する", obs.OBS_GROUP_CHECKABLE, seq_num_props)

	obs.obs_properties_add_text(props, "string_list", "文字列リスト", obs.OBS_TEXT_MULTILINE)
	obs.obs_properties_add_int_slider(props, "blank_time", "ブランク時間(ミリ秒)", BLANK_TIME["min"], BLANK_TIME["max"], BLANK_TIME["step"])

	-- Animation
	obs.obs_properties_add_int_slider(animation_props, "time_to_display", "結果表示までの時間(秒)", TIME_TO_DISPLAY["min"], TIME_TO_DISPLAY["max"], TIME_TO_DISPLAY["step"])
	obs.obs_properties_add_int_slider(animation_props, "roll_delay", "切り替え時間(ミリ秒)", ROLL_DELAY["min"], ROLL_DELAY["max"], ROLL_DELAY["step"])
	obs.obs_properties_add_int_slider(animation_props, "deceleration", "減速量(ミリ秒)", DECELERATION["min"], DECELERATION["max"], DECELERATION["step"])
	obs.obs_properties_add_path(bgm_props, "bgm_path", "オーディオファイルのパス", obs.OBS_PATH_FILE, "オーディオファイル(*.mp3 *.aac *ogg *.wav *.m4a);;すべてのファイル(*.*)", get_dir(Data.bgm_path))
	obs.obs_properties_add_group(animation_props, "with_bgm", "BGM再生を有効にする", obs.OBS_GROUP_CHECKABLE, bgm_props)
	obs.obs_properties_add_group(props, "with_animation", "アニメーションを有効にする", obs.OBS_GROUP_CHECKABLE, animation_props)

	-- Sound
	obs.obs_properties_add_path(sound_props, "sound_path", "オーディオファイルのパス", obs.OBS_PATH_FILE, "オーディオファイル(*.mp3 *.aac *ogg *.wav *.m4a);;すべてのファイル(*.*)", get_dir(Data.sound_path))
	obs.obs_properties_add_group(props, "play_sound", "結果表示時のオーディオファイル再生を有効にする", obs.OBS_GROUP_CHECKABLE, sound_props)

	obs.obs_properties_add_button(props, "get_random_btn", "抽選", function(obj, btn)
		on_get_random_click()
	end)

	return props
end
