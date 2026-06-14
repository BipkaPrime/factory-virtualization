data:extend({
	{ -- Virtualization Interface
		type = "recipe",
		name = "virtualization-interface",
		enabled = true,
		ingredients =
		{
			{ type = "item", name = "steel-plate", amount = 150 },
			{ type = "item", name = "stone-brick", amount = 40 },
			{ type = "item", name = "iron-chest", amount = 40 },
		},
		energy_required = 30,
		results = {{type="item", name="virtualization-interface", amount = 1}},
	}})