local FCT = {}
FCT.__index = FCT

function FCT.new()
	local self = setmetatable({}, FCT)
	self.results = {}
	self.categories = {}
	self.totalTested = 0
	self.totalWorking = 0
	self.totalPartial = 0
	self.totalFailed = 0
	self.totalFaked = 0
	self.extraCredit = 0
	self.extraCreditTotal = 0
	self.executorName = "Unknown Executor"
	self.platform = "Unknown"
	self.timeout = 10
	self.startTime = 0
	return self
end

function FCT:detectPlatform()
	pcall(function()
		local UserInputService = game:GetService("UserInputService")
		local touchEnabled = UserInputService.TouchEnabled
		local keyboardEnabled = UserInputService.KeyboardEnabled
		local mouseEnabled = UserInputService.MouseEnabled
		local accelerometerEnabled = UserInputService.AccelerometerEnabled
		local gyroscopeEnabled = UserInputService.GyroscopeEnabled
		
		if touchEnabled and not keyboardEnabled and not mouseEnabled then
			self.platform = "Mobile"
		elseif accelerometerEnabled or gyroscopeEnabled then
			self.platform = "Mobile"
		elseif keyboardEnabled and mouseEnabled then
			local isMac = false
			pcall(function()
				if string.find(string.lower(tostring(game:GetService("UserInputService").Platform)), "mac") then
					isMac = true
				end
			end)
			self.platform = isMac and "Mac" or "PC"
		else
			self.platform = "Console/Other"
		end
	end)
end

function FCT:getExecutorName()
	local methods = {
		function() return getexecutorname() end,
		function() return identifyexecutor() end,
		function() return getversion() end,
		function() return syn and syn.get_version and syn.get_version() end,
		function() return KRNL_LOADED and "Krnl" end,
		function() return syn and "Synapse X" end,
		function() return PROTOSMASHER_LOADED and "ProtoSmasher" end,
		function() return shadow_env and "Shadow" end,
		function() return WrapGlobal and "WeAreDevs" end,
		function() return isvm and "VMware" end,
		function() return _G.IS_FLUXUS_EXECUTOR and "Fluxus" end,
		function() return getgenv and pcall(getgenv) and getgenv().COMET_LOADED and "Comet" end,
		function() return EVON_LOADED and "Evon" end,
		function() return SCRIPTWARE and "Script-Ware" end,
		function() return ELECTRON and "Electron" end,
		function() return OXYGEN_U and "Oxygen U" end
	}
	
	for _, method in ipairs(methods) do
		pcall(function()
			local success, result = pcall(method)
			if success and result and type(result) == "string" and result ~= "" and result ~= "Unknown" then
				self.executorName = result
			end
		end)
	end
	
	return self.executorName
end

function FCT:testWithTimeout(testFunc, timeout)
	local completed = false
	local result = false
	local startTime = tick()
	local error_msg = nil
	
	local success = pcall(function()
		spawn(function()
			pcall(function()
				local testSuccess, testResult = pcall(testFunc)
				if testSuccess then
					result = testResult
				else
					error_msg = testResult
				end
				completed = true
			end)
		end)
		
		while not completed and (tick() - startTime) < timeout do
			wait(0.1)
		end
	end)
	
	if not success then
		return false, error_msg or "error"
	end
	
	if not completed then
		return false, "timeout"
	end
	
	return true, result
end

function FCT:isSynFunction(funcName)
	return string.find(funcName, "syn_") == 1
end

function FCT:hasAlternative(funcName)
	local alternatives = {
		["syn_request"] = {"httprequest", "http_request", "request"},
		["syn_getidentity"] = {"getidentity", "getthreadidentity"},
		["syn_setidentity"] = {"setidentity", "setthreadidentity"},
		["syn_protect_gui"] = {"protect_gui"},
		["syn_unprotect_gui"] = {"unprotect_gui"},
		["syn_crypt"] = {"crypt"}
	}
	
	if alternatives[funcName] then
		for _, alt in ipairs(alternatives[funcName]) do
			local success, func = pcall(function()
				return getgenv and getgenv()[alt] or _G[alt] or getfenv and getfenv()[alt]
			end)
			if success and func and type(func) == "function" then
				return true
			end
		end
	end
	
	return false
end

function FCT:testFunction(funcName, testFunc, category, isExtraCredit, alternativeNames)
	local success = pcall(function()
		if isExtraCredit then
			self.extraCreditTotal = self.extraCreditTotal + 1
		else
			self.totalTested = self.totalTested + 1
		end
		
		if not self.categories[category] then
			self.categories[category] = {working = 0, partial = 0, failed = 0, faked = 0, total = 0, extra = 0}
		end
		
		if not isExtraCredit then
			self.categories[category].total = self.categories[category].total + 1
		end
		
		local status = "❌"
		local note = ""
		local funcExists = false
		local isFaked = false
		local actualFuncName = funcName
		
		local allNames = {funcName}
		if alternativeNames then
			for _, alt in ipairs(alternativeNames) do
				table.insert(allNames, alt)
			end
		end
		
		local func = nil
		for _, name in ipairs(allNames) do
			local findSuccess, foundFunc = pcall(function()
				return getgenv and getgenv()[name] or _G[name] or getfenv and getfenv()[name]
			end)
			if findSuccess and foundFunc and type(foundFunc) == "function" then
				func = foundFunc
				actualFuncName = name
				funcExists = true
				break
			end
		end
		
		if funcExists then
			local fakeCheckSuccess = pcall(function()
				local funcStr = tostring(func)
				if string.find(funcStr, "warn") or string.find(funcStr, "not supported") or 
				   string.find(funcStr, "not available") or string.find(funcStr, "fake") then
					isFaked = true
				end
			end)
			
			if not fakeCheckSuccess then
				pcall(function()
					warn("Failed to check if " .. actualFuncName .. " is faked")
				end)
			end
		end
		
		if funcExists then
			if testFunc then
				local testCompleted, testResult = self:testWithTimeout(function()
					return testFunc(func)
				end, self.timeout)
				
				if not testCompleted then
					if testResult == "timeout" then
						if isFaked then
							status = "🔴"
							note = "faked function"
							if not isExtraCredit then
								self.totalFaked = self.totalFaked + 1
								self.categories[category].faked = self.categories[category].faked + 1
							end
						else
							status = "🟡"
							note = "slow yield"
							if not isExtraCredit then
								self.totalPartial = self.totalPartial + 1
								self.categories[category].partial = self.categories[category].partial + 1
							end
						end
					else
						status = "❌"
						note = "failed test"
						if not isExtraCredit then
							self.totalFailed = self.totalFailed + 1
							self.categories[category].failed = self.categories[category].failed + 1
						end
					end
					pcall(function()
						warn("Function " .. actualFuncName .. " test issue: " .. (testResult or "unknown error"))
					end)
				else
					local processSuccess = pcall(function()
						if testResult == true then
							if isFaked then
								status = "🔴"
								note = "faked function"
								if not isExtraCredit then
									self.totalFaked = self.totalFaked + 1
									self.categories[category].faked = self.categories[category].faked + 1
								end
							else
								status = isExtraCredit and "⭐" or "✅"
								if actualFuncName ~= funcName then
									note = "as " .. actualFuncName
								end
								if isExtraCredit then
									self.extraCredit = self.extraCredit + 1
									self.categories[category].extra = self.categories[category].extra + 1
								else
									self.totalWorking = self.totalWorking + 1
									self.categories[category].working = self.categories[category].working + 1
								end
							end
						elseif type(testResult) == "string" then
							status = "🟡"
							note = testResult
							if actualFuncName ~= funcName then
								note = note .. " as " .. actualFuncName
							end
							if not isExtraCredit then
								self.totalPartial = self.totalPartial + 1
								self.categories[category].partial = self.categories[category].partial + 1
							end
						else
							status = "🟡"
							note = "partial support"
							if actualFuncName ~= funcName then
								note = note .. " as " .. actualFuncName
							end
							if not isExtraCredit then
								self.totalPartial = self.totalPartial + 1
								self.categories[category].partial = self.categories[category].partial + 1
							end
						end
					end)
					
					if not processSuccess then
						status = "❌"
						note = "processing error"
						if not isExtraCredit then
							self.totalFailed = self.totalFailed + 1
							self.categories[category].failed = self.categories[category].failed + 1
						end
						pcall(function()
							warn("Failed to process test result for " .. actualFuncName)
						end)
					end
				end
			else
				if isFaked then
					status = "🔴"
					note = "faked function"
					if not isExtraCredit then
						self.totalFaked = self.totalFaked + 1
						self.categories[category].faked = self.categories[category].faked + 1
					end
				else
					status = isExtraCredit and "⭐" or "✅"
					if actualFuncName ~= funcName then
						note = "as " .. actualFuncName
					end
					if isExtraCredit then
						self.extraCredit = self.extraCredit + 1
						self.categories[category].extra = self.categories[category].extra + 1
					else
						self.totalWorking = self.totalWorking + 1
						self.categories[category].working = self.categories[category].working + 1
					end
				end
			end
		else
			if self:isSynFunction(funcName) and self:hasAlternative(funcName) then
				status = "🟡"
				note = "alt exists"
				if not isExtraCredit then
					self.totalPartial = self.totalPartial + 1
					self.categories[category].partial = self.categories[category].partial + 1
				end
			else
				if not isExtraCredit then
					self.totalFailed = self.totalFailed + 1
					self.categories[category].failed = self.categories[category].failed + 1
				end
			end
		end
		
		pcall(function()
			table.insert(self.results, {
				name = funcName,
				actualName = actualFuncName,
				category = category,
				status = status,
				note = note,
				exists = funcExists,
				faked = isFaked,
				extraCredit = isExtraCredit or false
			})
			
			local displayNote = note ~= "" and (" - " .. note) or ""
			local prefix = isExtraCredit and "[EXTRA] " or ""
			print(status .. " " .. prefix .. funcName .. displayNote)
		end)
	end)
	
	if not success then
		pcall(function()
			local prefix = isExtraCredit and "[EXTRA] " or ""
			print("❌ " .. prefix .. funcName .. " - test error")
			warn("Critical error testing function: " .. funcName)
			if not isExtraCredit then
				self.totalFailed = self.totalFailed + 1
				if self.categories[category] then
					self.categories[category].failed = self.categories[category].failed + 1
				end
			end
		end)
	end
end

function FCT:runTests()
	pcall(function()
		self.startTime = tick()
		self.executorName = self:getExecutorName()
		self:detectPlatform()
		
		print([[
┌─────────────────────────────────────────────────────────┐
│  _____ _____ _____                                      │
│ |   __|     |_   _|                                     │
│ |   __| | | | | |                                       │
│ |__|  |_|_|_| |_|                                       │
│                                                         │
│            Function Compatibility Test                  │
└─────────────────────────────────────────────────────────┘]])
		print("🎯 Executor: " .. self.executorName)
		print("💻 Platform: " .. self.platform)
		print("🕐 Started: " .. os.date("%H:%M:%S"))
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		
		print("\n🌐 [HTTP REQUESTS]")
		print("─────────────────────────")
		pcall(function()
			self:testFunction("httprequest", function(func)
				local testSuccess, response = pcall(function()
					return func({Url = "https://httpbin.org/get", Method = "GET", Headers = {}})
				end)
				if not testSuccess then return false end
				if not response then return false end
				if response.Success == false and response.StatusCode == 0 and response.Body == "" then return false end
				return response and response.Success == true and response.StatusCode == 200
			end, "HTTP", false, {"http_request", "syn_request", "request"})
			
			self:testFunction("http_request", function(func)
				local testSuccess, response = pcall(function()
					return func({Url = "https://httpbin.org/get", Method = "GET", Headers = {}})
				end)
				if not testSuccess then return false end
				if not response then return false end
				if response.Success == false and response.StatusCode == 0 and response.Body == "" then return false end
				return response and response.Success == true and response.StatusCode == 200
			end, "HTTP", false, {"httprequest", "syn_request", "request"})
			
			self:testFunction("syn_request", function(func)
				local testSuccess, response = pcall(function()
					return func({Url = "https://httpbin.org/get", Method = "GET", Headers = {}})
				end)
				if not testSuccess then return false end
				if not response then return false end
				if response.Success == false and response.StatusCode == 0 and response.Body == "" then return false end
				return response and response.Success == true and response.StatusCode == 200
			end, "HTTP", false, {"httprequest", "http_request", "request"})
			
			self:testFunction("request", function(func)
				local testSuccess, response = pcall(function()
					return func({Url = "https://httpbin.org/get", Method = "GET", Headers = {}})
				end)
				if not testSuccess then return false end
				if not response then return false end
				if response.Success == false and response.StatusCode == 0 and response.Body == "" then return false end
				return response and response.Success == true and response.StatusCode == 200
			end, "HTTP", false, {"httprequest", "http_request", "syn_request"})
		end)
		
		print("\n📁 [FILE SYSTEM]")
		print("─────────────────────────")
		pcall(function()
			self:testFunction("isfolder", function(func) 
				local result1 = func(".")
				local result2 = func("nonexistent_folder_12345")
				return result1 == true and result2 == false
			end, "FileSystem", false, {"isdir", "isdirectory"})
			
			self:testFunction("makefolder", function(func) 
				local testSuccess = pcall(function()
					func("fct_test_folder_12345")
				end)
				return testSuccess
			end, "FileSystem", false, {"mkdir", "makedirectory", "createfolder"})
			
			self:testFunction("delfolder", function(func) 
				local testSuccess = pcall(function()
					func("fct_test_folder_12345")
				end)
				return testSuccess
			end, "FileSystem", false, {"rmdir", "removefolder", "deletefolder"})
			
			self:testFunction("isfile", function(func) 
				local result = func("nonexistent_file_12345.txt")
				return result == false
			end, "FileSystem", false, {"fileexists"})
			
			self:testFunction("readfile", function(func) 
				local success = pcall(func, "nonexistent_file_12345.txt")
				return not success
			end, "FileSystem", false, {"getfile", "loadfile"})
			
			self:testFunction("writefile", function(func) 
				local testSuccess = pcall(function()
					func("fct_test_file_12345.txt", "test content for FCT")
				end)
				return testSuccess
			end, "FileSystem", false, {"savefile", "createfile"})
			
			self:testFunction("delfile", function(func) 
				local testSuccess = pcall(function()
					func("fct_test_file_12345.txt")
				end)
				return testSuccess
			end, "FileSystem", false, {"removefile", "deletefile"})
			
			self:testFunction("listfiles", function(func) 
				local testSuccess, files = pcall(func, ".")
				return testSuccess and type(files) == "table" and #files > 0
			end, "FileSystem", false, {"getfiles", "listdir"})
			
			self:testFunction("appendfile", function(func) 
				local testSuccess = pcall(function()
					func("fct_append_test_12345.txt", "additional content")
				end)
				return testSuccess
			end, "FileSystem", false, {"addtofile"})
			
			self:testFunction("loadfile", function(func) 
				return type(func) == "function"
			end, "FileSystem", false, {"dofile"})
		end)
		
		print("\n🖱️ [INPUT SIMULATION]")
		print("─────────────────────────")
		pcall(function()
			if self.platform == "PC" or self.platform == "Mac" then
				self:testFunction("mousemoverel", function(func) 
					local testSuccess = pcall(func, 0, 0)
					return testSuccess
				end, "Input", false, {"mouse_move_rel"})
				
				self:testFunction("mousemoveabs", function(func) 
					local testSuccess = pcall(func, 100, 100)
					return testSuccess
				end, "Input", false, {"mouse_move_abs"})
				
				self:testFunction("mouse1click", function(func) 
					local testSuccess = pcall(func)
					return testSuccess
				end, "Input", false, {"leftclick", "click"})
				
				self:testFunction("mouse1press", function(func) 
					local testSuccess = pcall(func)
					return testSuccess
				end, "Input", false, {"leftmousepress"})
				
				self:testFunction("mouse1release", function(func) 
					local testSuccess = pcall(func)
					return testSuccess
				end, "Input", false, {"leftmouserelease"})
				
				self:testFunction("mouse2click", function(func) 
					local testSuccess = pcall(func)
					return testSuccess
				end, "Input", false, {"rightclick"})
				
				self:testFunction("mouse2press", function(func) 
					local testSuccess = pcall(func)
					return testSuccess
				end, "Input", false, {"rightmousepress"})
				
				self:testFunction("mouse2release", function(func) 
					local testSuccess = pcall(func)
					return testSuccess
				end, "Input", false, {"rightmouserelease"})
				
				self:testFunction("mousescroll", function(func) 
					local testSuccess = pcall(func, 1)
					return testSuccess
				end, "Input", false, {"scrollmouse"})
				
				if self.platform == "PC" then
					self:testFunction("keypress", function(func) 
						local testSuccess = pcall(func, 0x41)
						return testSuccess
					end, "Input", false, {"key_press"})
					
					self:testFunction("keyrelease", function(func) 
						local testSuccess = pcall(func, 0x41)
						return testSuccess
					end, "Input", false, {"key_release"})
				elseif self.platform == "Mac" then
					self:testFunction("keypress_mac", function(func) 
						local testSuccess = pcall(func, 0x41)
						return testSuccess
					end, "Input", false, {"keypress", "key_press"})
					
					self:testFunction("keyrelease_mac", function(func) 
						local testSuccess = pcall(func, 0x41)
						return testSuccess
					end, "Input", false, {"keyrelease", "key_release"})
				end
				
				self:testFunction("iskeypressed", function(func) 
					local testSuccess, result = pcall(func, 0x41)
					return testSuccess and type(result) == "boolean"
				end, "Input", false, {"is_key_pressed"})
				
				self:testFunction("getmouseposition", function(func) 
					local testSuccess, pos = pcall(func)
					return testSuccess and type(pos) == "table" and pos.X and pos.Y
				end, "Input", false, {"get_mouse_pos", "mouseposition"})
			else
				print("🚫 Input simulation not tested on " .. self.platform .. " platform")
			end
		end)
		
		print("\n🪝 [FUNCTION HOOKING]")
		print("─────────────────────────")
		pcall(function()
			self:testFunction("hookfunction", function(func)
				local test = function() return "original" end
				local hookSuccess, original = pcall(func, test, function() return "hooked" end)
				if not hookSuccess then return false end
				local resultSuccess, result = pcall(test)
				if not resultSuccess then return false end
				local restoreSuccess = pcall(func, test, original)
				return result == "hooked" and restoreSuccess
			end, "Hooking", false, {"hook_function", "detour"})
			
			self:testFunction("hookmetamethod", function(func)
				local hookSuccess, original = pcall(func, game, "__namecall", function(...) return original(...) end)
				return hookSuccess and type(original) == "function"
			end, "Hooking", false, {"hook_metamethod"})
			
			self:testFunction("getrawmetamethod", function(func)
				local getSuccess, meta = pcall(func, game, "__namecall")
				return getSuccess and type(meta) == "function"
			end, "Hooking", false, {"get_raw_metamethod"})
			
			self:testFunction("newcclosure", function(func)
				local ccSuccess, closure = pcall(func, function() return "test" end)
				if not ccSuccess then return false end
				local callSuccess, result = pcall(closure)
				return callSuccess and result == "test"
			end, "Hooking", false, {"new_cclosure", "newclosure"})
			
			self:testFunction("getnamecallmethod", function(func)
				local getSuccess, method = pcall(func)
				return getSuccess and (type(method) == "string" or method == nil)
			end, "Hooking", false, {"get_namecall_method"})
			
			self:testFunction("restorefunction", function(func) 
				local restoreSuccess = pcall(func, print)
				return restoreSuccess
			end, "Hooking", false, {"restore_function"})
			
			self:testFunction("replaceclosure", function(func) 
				local replaceSuccess = pcall(func, print, print)
				return replaceSuccess
			end, "Hooking", false, {"replace_closure"})
			
			self:testFunction("clonefunction", function(func) 
				local cloneSuccess, clone = pcall(func, print)
				return cloneSuccess and type(clone) == "function" and clone ~= print
			end, "Hooking", false, {"clone_function"})
		end)
		
		print("\n🌍 [ENVIRONMENT]")
		print("─────────────────────────")
		pcall(function()
			self:testFunction("getgenv", function(func) 
				local getSuccess, env = pcall(func)
				return getSuccess and type(env) == "table" and env ~= _G
			end, "Environment", false, {"get_global_env", "getglobalenv"})
			
			self:testFunction("getrenv", function(func) 
				local getSuccess, env = pcall(func)
				return getSuccess and type(env) == "table"
			end, "Environment", false, {"get_roblox_env", "getrobloxenv"})
			
			self:testFunction("getfenv", function(func) 
				local getSuccess, env = pcall(func, 1)
				return getSuccess and type(env) == "table"
			end, "Environment", false, {"get_function_env"})
			
			self:testFunction("setfenv", function(func) 
				local testEnv = {test = true}
				local setSuccess = pcall(func, 1, testEnv)
				return setSuccess
			end, "Environment", false, {"set_function_env"})
			
			self:testFunction("getloadstring", function(func) 
				local getSuccess, ls = pcall(func)
				return getSuccess and type(ls) == "function"
			end, "Environment", false, {"get_loadstring"})
			
			self:testFunction("checkcaller", function(func) 
				local checkSuccess, result = pcall(func)
				return checkSuccess and type(result) == "boolean"
			end, "Environment", false, {"check_caller"})
			
			self:testFunction("islclosure", function(func) 
				local test1Success, result1 = pcall(func, print)
				local test2Success, result2 = pcall(func, function() end)
				return test1Success and test2Success and result1 == false and result2 == true
			end, "Environment", false, {"is_lclosure", "islua"})
			
			self:testFunction("iscclosure", function(func) 
				local test1Success, result1 = pcall(func, print)
				local test2Success, result2 = pcall(func, function() end)
				return test1Success and test2Success and result1 == true and result2 == false
			end, "Environment", false, {"is_cclosure", "isc"})
			
			self:testFunction("getgc", function(func) 
				local getSuccess, gc = pcall(func, true)
				return getSuccess and type(gc) == "table" and #gc > 0
			end, "Environment", false, {"get_gc_objects"})
			
			self:testFunction("gcinfo", function(func) 
				local getSuccess, info = pcall(func)
				return getSuccess and type(info) == "number" and info > 0
			end, "Environment", false, {"gc_info"})
			
			self:testFunction("getsenv", function(func) 
				local getSuccess, env = pcall(func, game.StarterPlayer)
				return getSuccess and type(env) == "table"
			end, "Environment", false, {"get_script_env"})
		end)
		
		print("\n🔍 [REFLECTION]")
		print("─────────────────────────")
		pcall(function()
			self:testFunction("getinstances", function(func) 
				local getSuccess, instances = pcall(func)
				return getSuccess and type(instances) == "table" and #instances > 0
			end, "Reflection", false, {"get_instances"})
			
			self:testFunction("getnilinstances", function(func) 
				local getSuccess, instances = pcall(func)
				return getSuccess and type(instances) == "table"
			end, "Reflection", false, {"get_nil_instances"})
			
			self:testFunction("getscripts", function(func) 
				local getSuccess, scripts = pcall(func)
				return getSuccess and type(scripts) == "table"
			end, "Reflection", false, {"get_scripts"})
			
			self:testFunction("getmodules", function(func) 
				local getSuccess, modules = pcall(func)
				return getSuccess and type(modules) == "table"
			end, "Reflection", false, {"get_modules"})
			
			self:testFunction("getconnections", function(func)
				local bindable = Instance.new("BindableEvent")
				local getSuccess, connections = pcall(func, bindable.Event)
				bindable:Destroy()
				return getSuccess and type(connections) == "table"
			end, "Reflection", false, {"get_connections"})
			
			self:testFunction("firesignal", function(func) 
				local fireSuccess = pcall(func, Instance.new("BindableEvent").Event)
				return fireSuccess
			end, "Reflection", false, {"fire_signal"})
			
			self:testFunction("fireclickdetector", function(func) 
				local detector = Instance.new("ClickDetector")
				local fireSuccess = pcall(func, detector)
				detector:Destroy()
				return fireSuccess
			end, "Reflection", false, {"fire_click_detector"})
			
			self:testFunction("fireproximityprompt", function(func) 
				local prompt = Instance.new("ProximityPrompt")
				local fireSuccess = pcall(func, prompt)
				prompt:Destroy()
				return fireSuccess
			end, "Reflection", false, {"fire_proximity_prompt"})
			
			self:testFunction("firetouchinterest", function(func) 
				local part = Instance.new("Part")
				local fireSuccess = pcall(func, part, part, 0)
				part:Destroy()
				return fireSuccess
			end, "Reflection", false, {"fire_touch_interest"})
			
			self:testFunction("getproperties", function(func) 
				local getSuccess, props = pcall(func, game)
				return getSuccess and type(props) == "table" and #props > 0
			end, "Reflection", false, {"get_properties"})
			
			self:testFunction("gethiddenproperty", function(func) 
				local getSuccess = pcall(func, game, "HttpEnabled")
				return getSuccess
			end, "Reflection", false, {"get_hidden_property"})
			
			self:testFunction("sethiddenproperty", function(func) 
				local setSuccess = pcall(func, game, "HttpEnabled", true)
				return setSuccess
			end, "Reflection", false, {"set_hidden_property"})
			
			self:testFunction("gethiddenproperties", function(func) 
				local getSuccess, props = pcall(func, game)
				return getSuccess and type(props) == "table"
			end, "Reflection", false, {"get_hidden_properties"})
		end)
		
		print("\n🛡️ [SECURITY]")
		print("─────────────────────────")
		pcall(function()
			self:testFunction("getidentity", function(func) 
				local getSuccess, id = pcall(func)
				return getSuccess and type(id) == "number" and id >= 0 and id <= 8
			end, "Security", false, {"get_identity", "getthreadidentity"})
			
			self:testFunction("setidentity", function(func) 
				local setSuccess = pcall(func, 2)
				return setSuccess
			end, "Security", false, {"set_identity", "setthreadidentity"})
			
			self:testFunction("syn_getidentity", function(func) 
				local getSuccess, id = pcall(func)
				return getSuccess and type(id) == "number" and id >= 0 and id <= 8
			end, "Security", false, {"getidentity", "getthreadidentity"})
			
			self:testFunction("syn_setidentity", function(func) 
				local setSuccess = pcall(func, 2)
				return setSuccess
			end, "Security", false, {"setidentity", "setthreadidentity"})
			
			self:testFunction("protect_gui", function(func) 
				local gui = Instance.new("ScreenGui")
				local protectSuccess = pcall(func, gui)
				gui:Destroy()
				return protectSuccess
			end, "Security", false, {"protectgui", "syn_protect_gui"})
			
			self:testFunction("unprotect_gui", function(func) 
				local gui = Instance.new("ScreenGui")
				local unprotectSuccess = pcall(func, gui)
				gui:Destroy()
				return unprotectSuccess
			end, "Security", false, {"unprotectgui", "syn_unprotect_gui"})
			
			self:testFunction("syn_protect_gui", function(func) 
				local gui = Instance.new("ScreenGui")
				local protectSuccess = pcall(func, gui)
				gui:Destroy()
				return protectSuccess
			end, "Security", false, {"protect_gui", "protectgui"})
			
			self:testFunction("syn_unprotect_gui", function(func) 
				local gui = Instance.new("ScreenGui")
				local unprotectSuccess = pcall(func, gui)
				gui:Destroy()
				return unprotectSuccess
			end, "Security", false, {"unprotect_gui", "unprotectgui"})
			
			self:testFunction("isreadonly", function(func) 
				local tbl = {}
				local readSuccess, isReadonly = pcall(func, tbl)
				return readSuccess and isReadonly == false
			end, "Security", false, {"is_readonly"})
			
			self:testFunction("setreadonly", function(func) 
				local tbl = {}
				local setSuccess = pcall(func, tbl, true)
				return setSuccess
			end, "Security", false, {"set_readonly"})
			
			self:testFunction("setthreadidentity", function(func) 
				local setSuccess = pcall(func, 2)
				return setSuccess
			end, "Security", false, {"set_thread_identity", "setidentity"})
			
			self:testFunction("getthreadidentity", function(func) 
				local getSuccess, id = pcall(func)
				return getSuccess and type(id) == "number"
			end, "Security", false, {"get_thread_identity", "getidentity"})
		end)
		
		print("\n💻 [CONSOLE]")
		print("─────────────────────────")
		pcall(function()
			self:testFunction("rconsoleprint", function(func) 
				local printSuccess = pcall(func, "FCT Test")
				return printSuccess
			end, "Console", false, {"rprint", "consoleprint"})
			
			self:testFunction("rconsoleclear", function(func) 
				local clearSuccess = pcall(func)
				return clearSuccess
			end, "Console", false, {"rclear", "consoleclear"})
			
			self:testFunction("rconsolename", function(func) 
				local nameSuccess = pcall(func, "FCT Console")
				return nameSuccess
			end, "Console", false, {"rname", "consolename"})
			
			self:testFunction("rconsolecreate", function(func) 
				local createSuccess = pcall(func)
				return createSuccess
			end, "Console", false, {"rcreate", "consolecreate"})
			
			self:testFunction("rconsoleclose", function(func) 
				local closeSuccess = pcall(func)
				return closeSuccess
			end, "Console", false, {"rclose", "consoleclose"})
			
			self:testFunction("rconsoleinput", function(func) 
				local inputSuccess = pcall(func)
				return inputSuccess
			end, "Console", false, {"rinput", "consoleinput"})
			
			self:testFunction("rconsoleinfo", function(func) 
				local infoSuccess = pcall(func, "info message")
				return infoSuccess
			end, "Console", false, {"rinfo", "consoleinfo"})
			
			self:testFunction("rconsolewarn", function(func) 
				local warnSuccess = pcall(func, "warning message")
				return warnSuccess
			end, "Console", false, {"rwarn", "consolewarn"})
			
			self:testFunction("rconsoleerr", function(func) 
				local errSuccess = pcall(func, "error message")
				return errSuccess
			end, "Console", false, {"rerr", "rconsoleerror", "consoleerr"})
		end)
		
		print("\n📋 [CLIPBOARD]")
		print("─────────────────────────")
		pcall(function()
			self:testFunction("setclipboard", function(func) 
				local setSuccess = pcall(func, "FCT clipboard test")
				return setSuccess
			end, "Clipboard", false, {"set_clipboard", "toclipboard"})
			
			self:testFunction("getclipboard", function(func) 
				local getSuccess, clip = pcall(func)
				return getSuccess and type(clip) == "string"
			end, "Clipboard", false, {"get_clipboard"})
			
			self:testFunction("toclipboard", function(func) 
				local toSuccess = pcall(func, "FCT clipboard test")
				return toSuccess
			end, "Clipboard", false, {"setclipboard", "set_clipboard"})
		end)
		
		print("\n🧠 [MEMORY]")
		print("─────────────────────────")
		pcall(function()
			self:testFunction("readbytes", function(func) 
				local readSuccess = pcall(func, 0, 1)
				return readSuccess
			end, "Memory", false, {"read_bytes"})
			
			self:testFunction("writebytes", function(func) 
				local writeSuccess = pcall(func, 0, {0x90})
				return writeSuccess
			end, "Memory", false, {"write_bytes"})
			
			self:testFunction("virtualprotect", function(func) 
				local protectSuccess = pcall(func, 0, 1, 0x40)
				return protectSuccess
			end, "Memory", false, {"virtual_protect"})
			
			self:testFunction("virtualalloc", function(func) 
				local allocSuccess = pcall(func, 0, 1, 0x1000, 0x40)
				return allocSuccess
			end, "Memory", false, {"virtual_alloc"})
			
			self:testFunction("virtualfree", function(func) 
				local freeSuccess = pcall(func, 0, 1, 0x8000)
				return freeSuccess
			end, "Memory", false, {"virtual_free"})
			
			self:testFunction("readmem", function(func) 
				local readSuccess = pcall(func, 0, "int")
				return readSuccess
			end, "Memory", false, {"read_memory"})
			
			self:testFunction("writemem", function(func) 
				local writeSuccess = pcall(func, 0, "int", 0)
				return writeSuccess
			end, "Memory", false, {"write_memory"})
			
			self:testFunction("allocatecodecave", function(func) 
				local allocSuccess = pcall(func, 1024)
				return allocSuccess
			end, "Memory", false, {"allocate_code_cave"})
		end)
		
		print("\n🐞 [DEBUG]")
		print("─────────────────────────")
		pcall(function()
			self:testFunction("debug.getupvalue", function(func) 
				local getSuccess = pcall(func, print, 1)
				return getSuccess
			end, "Debug", false, {"debug.get_upvalue"})
			
			self:testFunction("debug.setupvalue", function(func) 
				local setSuccess = pcall(func, print, 1, nil)
				return setSuccess
			end, "Debug", false, {"debug.set_upvalue"})
			
			self:testFunction("debug.getupvalues", function(func) 
				local getSuccess, upvalues = pcall(func, print)
				return getSuccess and type(upvalues) == "table"
			end, "Debug", false, {"debug.get_upvalues"})
			
			self:testFunction("debug.setconstant", function(func) 
				local setSuccess = pcall(func, print, 1, nil)
				return setSuccess
			end, "Debug", false, {"debug.set_constant"})
			
			self:testFunction("debug.getconstant", function(func) 
				local getSuccess = pcall(func, print, 1)
				return getSuccess
			end, "Debug", false, {"debug.get_constant"})
			
			self:testFunction("debug.getconstants", function(func) 
				local getSuccess, constants = pcall(func, print)
				return getSuccess and type(constants) == "table"
			end, "Debug", false, {"debug.get_constants"})
			
			self:testFunction("debug.getproto", function(func) 
				local getSuccess = pcall(func, print, 1)
				return getSuccess
			end, "Debug", false, {"debug.get_proto"})
			
			self:testFunction("debug.getprotos", function(func) 
				local getSuccess, protos = pcall(func, print)
				return getSuccess and type(protos) == "table"
			end, "Debug", false, {"debug.get_protos"})
			
			self:testFunction("debug.setstack", function(func) 
				local setSuccess = pcall(func, 1, 1, nil)
				return setSuccess
			end, "Debug", false, {"debug.set_stack"})
			
			self:testFunction("debug.getstack", function(func) 
				local getSuccess = pcall(func, 1, 1)
				return getSuccess
			end, "Debug", false, {"debug.get_stack"})
			
			self:testFunction("debug.getinfo", function(func) 
				local getSuccess, info = pcall(func, 1)
				return getSuccess and type(info) == "table"
			end, "Debug", false, {"debug.get_info"})
			
			self:testFunction("debug.profilebegin", function(func) 
				local profileSuccess = pcall(func, "test")
				return profileSuccess
			end, "Debug", false, {"debug.profile_begin"})
			
			self:testFunction("debug.profileend", function(func) 
				local profileSuccess = pcall(func)
				return profileSuccess
			end, "Debug", false, {"debug.profile_end"})
		end)
		
		print("\n⚡ [BYTECODE]")
		print("─────────────────────────")
		pcall(function()
			self:testFunction("getscriptbytecode", function(func) 
				local getSuccess, bytecode = pcall(func, game.StarterPlayer)
				return getSuccess and type(bytecode) == "string"
			end, "Bytecode", false, {"get_script_bytecode"})
			
			self:testFunction("getscripthash", function(func) 
				local getSuccess, hash = pcall(func, game.StarterPlayer)
				return getSuccess and type(hash) == "string"
			end, "Bytecode", false, {"get_script_hash"})
			
			self:testFunction("dumpstring", function(func) 
				local dumpSuccess, dump = pcall(func, "print('test')")
				return dumpSuccess and type(dump) == "string"
			end, "Bytecode", false, {"dump_string"})
			
			self:testFunction("decompile", function(func) 
				local decompileSuccess, source = pcall(func, game.StarterPlayer)
				return decompileSuccess and type(source) == "string"
			end, "Bytecode", false, {"decompile_script"})
			
			self:testFunction("disassemble", function(func) 
				local disSuccess, assembly = pcall(func, print)
				return disSuccess and type(assembly) == "string"
			end, "Bytecode", false, {"disassemble_function"})
		end)
		
		print("\n🔐 [CRYPTOGRAPHY]")
		print("─────────────────────────")
		pcall(function()
			self:testFunction("crypt.base64encode", function(func) 
				local encSuccess, result = pcall(func, "test")
				return encSuccess and type(result) == "string" and result ~= "test" and result == "dGVzdA=="
			end, "Crypt", false, {"crypt.base64_encode", "base64encode"})
			
			self:testFunction("crypt.base64decode", function(func) 
				local decSuccess, result = pcall(func, "dGVzdA==")
				return decSuccess and result == "test"
			end, "Crypt", false, {"crypt.base64_decode", "base64decode"})
			
			self:testFunction("crypt.encrypt", function(func) 
				local encSuccess, encrypted = pcall(func, "test", "key")
				return encSuccess and type(encrypted) == "string" and encrypted ~= "test"
			end, "Crypt", false, {"crypt.encrypt_data"})
			
			self:testFunction("crypt.decrypt", function(func) 
				local decSuccess = pcall(func, "encrypted", "key")
				return decSuccess
			end, "Crypt", false, {"crypt.decrypt_data"})
			
			self:testFunction("crypt.generatekey", function(func) 
				local genSuccess, key = pcall(func)
				return genSuccess and type(key) == "string" and #key > 0
			end, "Crypt", false, {"crypt.generate_key"})
			
			self:testFunction("crypt.hash", function(func) 
				local hashSuccess, hash = pcall(func, "test")
				return hashSuccess and type(hash) == "string" and #hash > 0 and hash ~= "test"
			end, "Crypt", false, {"crypt.hash_data"})
			
			self:testFunction("crypt.random", function(func) 
				local randSuccess, random = pcall(func, 16)
				return randSuccess and type(random) == "string" and #random > 0
			end, "Crypt", false, {"crypt.generate_random"})
			
			self:testFunction("crypt.custom", function(func) 
				local custSuccess = pcall(func, "test", "key", "algorithm")
				return custSuccess
			end, "Crypt", false, {"crypt.custom_encrypt"})
		end)
		
		print("\n🔢 [BIT OPERATIONS]")
		print("─────────────────────────")
		pcall(function()
			self:testFunction("bit32.band", function(func) 
				local bandSuccess, result = pcall(func, 5, 3)
				return bandSuccess and result == 1
			end, "BitOps")
			
			self:testFunction("bit32.bor", function(func) 
				local borSuccess, result = pcall(func, 5, 3)
				return borSuccess and result == 7
			end, "BitOps")
			
			self:testFunction("bit32.bxor", function(func) 
				local bxorSuccess, result = pcall(func, 5, 3)
				return bxorSuccess and result == 6
			end, "BitOps")
		end)
		
		print("\n🎨 [SPECIAL OBJECTS]")
		print("─────────────────────────")
		pcall(function()
			self:testFunction("Drawing", function()
				if Drawing and Drawing.new then
					local createSuccess, circle = pcall(Drawing.new, "Circle")
					if not createSuccess then return false end
					local isValid = circle ~= nil and type(circle) == "userdata"
					if circle and circle.Remove then
						pcall(circle.Remove, circle)
					end
					return isValid
				end
				return false
			end, "Drawing")
			
			self:testFunction("WebSocket", function()
				return WebSocket and WebSocket.connect ~= nil and type(WebSocket.connect) == "function"
			end, "WebSocket")
			
			self:testFunction("syn_crypt", function()
				return syn_crypt and type(syn_crypt) == "table" and syn_crypt.base64 ~= nil
			end, "Crypto", false, {"crypt"})
		end)
		
		print("\n💾 [CACHE]")
		print("─────────────────────────")
		pcall(function()
			self:testFunction("cache.invalidate", function(func) 
				local invSuccess = pcall(func, game)
				return invSuccess
			end, "Cache", false, {"cache.invalidate_instance"})
			
			self:testFunction("cache.iscached", function(func) 
				local checkSuccess, result = pcall(func, game)
				return checkSuccess and type(result) == "boolean"
			end, "Cache", false, {"cache.is_cached"})
			
			self:testFunction("cache.replace", function(func) 
				local replSuccess = pcall(func, game, game)
				return replSuccess
			end, "Cache", false, {"cache.replace_instance"})
			
			self:testFunction("cloneref", function(func) 
				local cloneSuccess, ref = pcall(func, game)
				return cloneSuccess and ref ~= nil and ref ~= game
			end, "Cache", false, {"clone_ref"})
			
			self:testFunction("compareinstances", function(func) 
				local compSuccess, result = pcall(func, game, game)
				return compSuccess and result == true
			end, "Cache", false, {"compare_instances"})
		end)
		
		print("\n🔧 [MISC]")
		print("─────────────────────────")
		pcall(function()
			self:testFunction("isrbxactive", function(func) 
				local getSuccess, result = pcall(func)
				return getSuccess and type(result) == "boolean"
			end, "Misc", false, {"is_rbx_active", "isgameactive"})
			
			self:testFunction("isgameactive", function(func) 
				local getSuccess, result = pcall(func)
				return getSuccess and type(result) == "boolean"
			end, "Misc", false, {"is_game_active", "isrbxactive"})
			
			self:testFunction("setfpscap", function(func) 
				local setSuccess = pcall(func, 60)
				return setSuccess
			end, "Misc", false, {"set_fps_cap"})
			
			self:testFunction("getfpscap", function(func) 
				local getSuccess, fps = pcall(func)
				return getSuccess and type(fps) == "number" and fps > 0
			end, "Misc", false, {"get_fps_cap"})
			
			self:testFunction("setfflag", function(func) 
				local setSuccess = pcall(func, "DFIntTaskSchedulerTargetFps", "60")
				return setSuccess
			end, "Misc", false, {"set_fflag"})
			
			self:testFunction("getfflag", function(func) 
				local getSuccess, flag = pcall(func, "DFIntTaskSchedulerTargetFps")
				return getSuccess
			end, "Misc", false, {"get_fflag"})
			
			self:testFunction("saveinstance", function(func) 
				local saveSuccess = pcall(func, game)
				return saveSuccess
			end, "Misc", false, {"save_instance"})
			
			self:testFunction("messagebox", function(func) 
				local msgSuccess = pcall(func, "FCT Test", "Test", 0)
				return msgSuccess
			end, "Misc", false, {"message_box"})
			
			self:testFunction("queue_on_teleport", function(func) 
				local queueSuccess = pcall(func, "print('FCT teleport test')")
				return queueSuccess
			end, "Misc", false, {"queueonteleport"})
			
			self:testFunction("getexecutorname", function(func) 
				local getSuccess, name = pcall(func)
				return getSuccess and type(name) == "string" and name ~= ""
			end, "Misc", false, {"get_executor_name", "identifyexecutor"})
			
			self:testFunction("identifyexecutor", function(func) 
				local getSuccess, name = pcall(func)
				return getSuccess and type(name) == "string" and name ~= ""
			end, "Misc", false, {"identify_executor", "getexecutorname"})
			
			self:testFunction("getversion", function(func) 
				local getSuccess, version = pcall(func)
				return getSuccess and type(version) == "string" and version ~= ""
			end, "Misc", false, {"get_version"})
		end)
		
		print("\n⭐ [EXTRA FEATURES]")
		print("─────────────────────────")
		pcall(function()
			self:testFunction("getscriptclosure", function(func) 
				local getSuccess, closure = pcall(func, game.StarterPlayer)
				return getSuccess and type(closure) == "function"
			end, "Extra", true, {"get_script_closure"})
			
			self:testFunction("getloadedmodules", function(func) 
				local getSuccess, modules = pcall(func)
				return getSuccess and type(modules) == "table"
			end, "Extra", true, {"get_loaded_modules"})
			
			self:testFunction("getrunningscripts", function(func) 
				local getSuccess, scripts = pcall(func)
				return getSuccess and type(scripts) == "table"
			end, "Extra", true, {"get_running_scripts"})
			
			self:testFunction("dumpobj", function(func) 
				local dumpSuccess, dump = pcall(func, game)
				return dumpSuccess and type(dump) == "string"
			end, "Extra", true, {"dump_object"})
			
			self:testFunction("getinfo", function(func) 
				local getSuccess, info = pcall(func, 1)
				return getSuccess and type(info) == "table"
			end, "Extra", true, {"get_info"})
			
			self:testFunction("Drawing.Fonts", function() 
				return Drawing and Drawing.Fonts ~= nil and type(Drawing.Fonts) == "table"
			end, "Extra", true)
			
			self:testFunction("getsynasset", function(func) 
				local getSuccess, asset = pcall(func, "test.txt")
				return getSuccess and type(asset) == "string"
			end, "Extra", true, {"get_syn_asset"})
			
			self:testFunction("getcustomasset", function(func) 
				local getSuccess, asset = pcall(func, "test.txt")
				return getSuccess and type(asset) == "string"
			end, "Extra", true, {"get_custom_asset"})
			
			self:testFunction("getspecialinfo", function(func) 
				local getSuccess, info = pcall(func, game)
				return getSuccess and type(info) == "table"
			end, "Extra", true, {"get_special_info"})
			
			self:testFunction("isnetworkowner", function(func) 
				local part = Instance.new("Part")
				local checkSuccess, result = pcall(func, part)
				part:Destroy()
				return checkSuccess and type(result) == "boolean"
			end, "Extra", true, {"is_network_owner"})
		end)
		
		self:printSummary()
	end)
end

function FCT:printSummary()
	pcall(function()
		local endTime = tick()
		local testTime = endTime - self.startTime
		local successRate = self.totalTested > 0 and math.floor((self.totalWorking / self.totalTested) * 100) or 0
		
		local rating = ""
		if successRate >= 95 then
			rating = "PERFECT"
		elseif successRate >= 80 then
			rating = "EXCELLENT"
		elseif successRate >= 70 then
			rating = "VERY GOOD"
		elseif successRate >= 60 then
			rating = "GOOD"
		elseif successRate >= 50 then
			rating = "OKAY"
		elseif successRate >= 40 then
			rating = "FAIR"
		elseif successRate >= 30 then
			rating = "POOR"
		else
			rating = "TERRIBLE"
		end
		
		print([[

┌─────────────────────────────────────────────────────────┐
│  ____  _____ ____  _   _ _   _____ ____                 │
│ |  _ \| ____/ ___|| | | | | |_   _/ ___|                │
│ | |_) |  _| \___ \| | | | |   | | \___ \                │
│ |  _ <| |___ ___) | |_| | |___| |  ___) |               │
│ |_| \_\_____|____/ \___/|_____|_| |____/                │
│                                                         │
│                  Test Results                           │
└─────────────────────────────────────────────────────────┘]])

		print("┌─" .. string.rep("─", 57) .. "─┐")
		print("│ 📊 OVERALL STATISTICS" .. string.rep(" ", 34) .. "│")
		print("├─" .. string.rep("─", 57) .. "─┤")
		print("│ ✅ Passed: " .. string.format("%-8d", self.totalWorking) .. "🟡 Partial: " .. string.format("%-8d", self.totalPartial) .. "❌ Failed: " .. string.format("%-7d", self.totalFailed) .. "│")
		print("│ 🔴 Faked: " .. string.format("%-9d", self.totalFaked) .. "⭐ Extra: " .. string.format("%-10d", self.extraCredit) .. "📈 Rate: " .. string.format("%-8s", successRate .. "%") .. "│")
		print("│ ⏱️  Test Time: " .. string.format("%.2f", testTime) .. " seconds" .. string.rep(" ", 30) .. "│")
		print("└─" .. string.rep("─", 57) .. "─┘")
		
		print("\n┌─" .. string.rep("─", 57) .. "─┐")
		print("│ 📂 BREAKDOWN BY CATEGORY" .. string.rep(" ", 32) .. "│")
		print("├─" .. string.rep("─", 57) .. "─┤")
		
		for category, stats in pairs(self.categories) do
			local catSuccess = stats.total > 0 and math.floor((stats.working / stats.total) * 100) or 0
			local fakedText = stats.faked > 0 and (" 🔴" .. stats.faked) or ""
			local extraText = stats.extra > 0 and (" ⭐" .. stats.extra) or ""
			local line = "│ " .. string.format("%-12s", category) .. ": " .. 
						 string.format("%-2d", stats.working) .. "/" .. string.format("%-2d", stats.total) .. 
						 " (" .. string.format("%-3d", catSuccess) .. "%)" .. fakedText .. extraText
			line = line .. string.rep(" ", 59 - #line) .. "│"
			print(line)
		end
		print("└─" .. string.rep("─", 57) .. "─┘")
		
		print("\n┌─" .. string.rep("─", 57) .. "─┐")
		print("│ 🏆 EXECUTOR RATING" .. string.rep(" ", 39) .. "│")
		print("├─" .. string.rep("─", 57) .. "─┤")
		
		local description
		if successRate >= 95 then
			description = "Perfect executor with full support."
		elseif successRate >= 80 then
			description = "Amazing executor with excellent support."
		elseif successRate >= 70 then
			description = "Very good executor with solid support."
		elseif successRate >= 60 then
			description = "Decent executor with good support."
		elseif successRate >= 50 then
			description = "Acceptable executor with moderate support."
		elseif successRate >= 40 then
			description = "Basic executor with limited support."
		elseif successRate >= 30 then
			description = "Poor executor with minimal support."
		else
			description = "Terrible executor that barely works."
		end
		
		print("│ " .. string.format("%-15s", "🌟 " .. rating) .. description .. string.rep(" ", 58 - #rating - #description - 2) .. "│")
		
		if self.totalFaked > 0 then
			print("│ ⚠️  WARNING: " .. self.totalFaked .. " functions appear to be faked!" .. string.rep(" ", 23) .. "│")
		end
		
		print("└─" .. string.rep("─", 57) .. "─┘")
		
		print("\n┌─" .. string.rep("─", 57) .. "─┐")
		print("│ ℹ️  TEST INFO" .. string.rep(" ", 44) .. "│")
		print("├─" .. string.rep("─", 57) .. "─┤")
		print("│ 🎯 Executor: " .. string.format("%-43s", self.executorName) .. "│")
		print("│ 💻 Platform: " .. string.format("%-43s", self.platform) .. "│")
		print("│ 🕐 Completed: " .. string.format("%-42s", os.date("%H:%M:%S")) .. "│")
		print("│ ⚡ Duration: " .. string.format("%.2f", testTime) .. " seconds" .. string.rep(" ", 34) .. "│")
		print("└─" .. string.rep("─", 57) .. "─┘")
		
		if self.extraCredit > 0 then
			print("\n Extra Score: " .. self.extraCredit .. "/" .. self.extraCreditTotal .. " extra features supported!")
		end
		
		if self.totalFaked > 0 then
			print("\n⚠️  " .. self.totalFaked .. " functions detected as faked - they exist but don't work properly!")
		end
	end)
end

print("🚀 Starting FCT...")
local fct = FCT.new()
fct:runTests()
