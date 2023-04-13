export type connection = {
	Disconnect: (self:connection)->();
	Destroy: (self:connection)->();
	New: (bindable,(...any)->())->();
}
export type bindable = {
	Fire: (self:bindable,...any)->();
	Wait: (self:bindable)->();
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
}
export type init = ()->module

return require(script.spring) :: module & { Init: init }
