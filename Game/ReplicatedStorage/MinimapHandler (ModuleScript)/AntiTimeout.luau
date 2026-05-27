type Array<T> = {[number]:T}
type Dictionary<T1, T2> = {[T1]:T2}
type TimeoutData = {MaxTime:number, LastTick:number}
local RegisteredData:Dictionary<string, TimeoutData> = {}
local Module = {}
function Module.Register(Name:string, MaxTime:number)
	assert(typeof(Name) == "string")
	assert(typeof(MaxTime) == "number")
	
	RegisteredData[Name] = {MaxTime = MaxTime, LastTick = tick()}
end
function Module.Checkup(Name:string):boolean
	local RegisteredData = RegisteredData[Name]
	assert(RegisteredData, `The given name ("`..Name..`") is not registered!`)
	local MaxTime, LastTick = RegisteredData.MaxTime, RegisteredData.LastTick
	if tick() - LastTick >= MaxTime then
		task.wait() --Wait to prevent timeout
		RegisteredData.LastTick = tick()
		return true
	else
		return false
	end
end

function Module.Remove(Name:string)
	RegisteredData[Name] = nil
end

return Module