--!strict

export type Controller = {
	Name: string,
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

return table.freeze({})
