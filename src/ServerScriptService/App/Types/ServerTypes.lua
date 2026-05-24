--!strict

export type Service = {
	Name: string,
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

return table.freeze({})
