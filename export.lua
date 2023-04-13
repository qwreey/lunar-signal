export type connection = {
	Disconnect: (self:connection)->();
	Destroy: (self:connection)->();
	New: (bindable,(...any)->())->();
}
export type timeouted = {}
export type released = {}
export type bindable = {
	Fire: (self:bindable,...any)->();
	FireSync: (self:bindable,...any)->();
	ReleaseWaittings: (self:bindable)->();
	DisconnectAll: (self:bindable,releaseWaittings:boolean?)->();
	Wait: (self:bindable,timeoutInSecond:number?)->(released|timeouted|any,...any);
	CheckConnected: (self:bindable,(...any)->())->boolean;
	Connect: (self:bindable,(...any)->())->connection;
	Once: (self:bindable,(...any)->())->connection;
	Destroy: (self:bindable)->();
	New: (id:string?)->bindable;
}
export type disconnecter = {
	Add: (self:disconnecter,connection:RBXScriptConnection)->();
	Destroy: (self:disconnecter)->();
	Disconnect: (self:disconnecter)->();
	New: (id:string?)->disconnecter;
}
export type id = string
export type module = {
	Disconnecter: disconnecter,
	DisconnecterList: {[id]:disconnecter},
	Connection: connection,
	BindableList: {[id]:bindable},
	Bindable: bindable,
	Timeouted: timeouted,
	Released: released
}
export type init = ()->module

return require(script.spring) :: module & { Init: init }
