local interface = {
	get = ui.get,
	set = ui.set,
	ref = ui.reference,
	callback = ui.set_callback,
	checkbox = ui.new_checkbox,
	visible = ui.set_visible,
	slider = ui.new_slider
}

local ent = {
	get_local = entity.get_local_player,
	get_prop = entity.get_prop,
	get_all = entity.get_all
}

local cl = {
	indicator = client.draw_indicator,
	draw = client.draw_text,
	size = client.screen_size,
	exec = client.exec,
	ute = client.userid_to_entindex,
	latency = client.latency,
	tickcount = globals.tickcount,
	curtime = globals.curtime,
	realtime = globals.realtime
}

local release_at = nil
local flag, flag_hotkey = interface.ref("AA", "Fake lag", "Enabled")
local slowmo, slowmo_hotkey = interface.ref("AA", "Other", "Slow motion")
local pingspike, pingspike_hotkey = interface.ref("MISC", "Miscellaneous", "Ping spike")

local apr_active = interface.checkbox("MISC", "Miscellaneous", "Anti pingspike reset")
local apr_maximum = interface.slider("MISC", "Miscellaneous", "Maximum ping", 1, 750, 250, true, "ms")

local function getlatency()

	local prop = ent.get_all("CCSPlayerResource")[1]
	local g_ServerLatency = ent.get_prop(prop, string.format("%03d", ent.get_local()))
	local g_RealLatency = math.floor(math.min(1000, cl.latency() * 1000) + 0.5)

	g_ServerLatency = (g_ServerLatency > 999 and 999 or g_ServerLatency)

	local g_DeclLatency = g_ServerLatency - g_RealLatency
	if g_DeclLatency < 1 then g_DeclLatency = 1 end

	return g_ServerLatency, g_RealLatency, g_DeclLatency
	
end

local function setMath(int, max, declspec)
	local int = (int > max and max or int)

	local tmp = max / int;
	local i = (declspec / tmp)
	i = (i >= 0 and math.floor(i + 0.5) or math.ceil(i - 0.5))

	return i
end

local function getColor(number, max)
	local r, g, b
	local i = setMath(number, max, 9)

	if i == 9 then r, g, b = 255, 0, 0
		elseif i == 8 then r, g, b = 237, 27, 3
		elseif i == 7 then r, g, b = 235, 63, 6
		elseif i == 6 then r, g, b = 229, 104, 8
		elseif i == 5 then r, g, b = 228, 126, 10
		elseif i == 4 then r, g, b = 220, 169, 16
		elseif i == 3 then r, g, b = 213, 201, 19
		elseif i == 2 then r, g, b = 176, 205, 10
		elseif i <= 1 then r, g, b = 124, 195, 13
	end

	return r, g, b
end

local function isActive(ping, warn)
	if warn == 0 then
		return interface.get(apr_active) and not (interface.get(apr_maximum) > ping)
	else
		return interface.get(apr_active) and not interface.get(pingspike_hotkey) and (interface.get(apr_maximum) <= ping)
	end
end

local function visibility(this)
	interface.visible(apr_maximum, interface.get(this))
end

-- Event Functions

local i, timechange = 0, 0
local function on_item_equip(e)
	local userid, canzoom, item = e.userid, e.canzoom, e.item
	if userid == nil or i < 1 then return end
	if cl.ute(userid) == ent.get_local() then
		if item == "scar20" or item == "sg556" then
			cl.exec("-attack2; -lookatweapon; +attack2; +lookatweapon")
			release_at = cl.realtime() + 0.1
		else
			if release_at ~= nil then
				cl.exec("-attack2; -lookatweapon")
				release_at = nil
			end
		end
	end
end

local function on_paint(c)
	if ent.get_prop(ent.get_local(), "m_iHealth") <= 0 then
		return
	end

	local alpha = 255
	local g_rLat, g_sLat, g_dLat = getlatency()
	if interface.get(apr_active) then
		interface.set(flag, not (interface.get(pingspike_hotkey) and interface.get(apr_maximum) <= g_rLat))
	end

	local pNum, d = setMath(g_dLat, 250, 20)
	if i ~= pNum and timechange < cl.curtime() then
		if i > pNum then d = -1 else d = 1 end
		
		timechange = cl.curtime() + 0.2
		i = i + d
	end

	local r, g, b = getColor(i, 20)
	if not (interface.get(flag) and not isActive(g_rLat, 0)) then	
		r, g, b = 255, 255, 255

		local tickcount = (cl.tickcount() % 127.5)
		if isActive(g_rLat, 1) then
			if tickcount > 63.75 then
				alpha = 255 - (tickcount * 4)
			else
				alpha = tickcount * 4
			end
		end

	end

	if i >= 1 then
		cl.indicator(c, r, g, b, alpha, i) -- Lag Factor

		if release_at ~= nil and release_at < cl.realtime() then
			release_at = nil
			cl.exec("-attack2; -lookatweapon; +lookatweapon; -lookatweapon")
		end
	end
end

interface.callback(apr_active, visibility)
client.set_event_callback("paint", on_paint)
client.set_event_callback("item_equip", on_item_equip)