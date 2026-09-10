local tips_category = {
    type = "tips-and-tricks-item-category",
    name = PREFIX .. "tips",
    order = "a" .. PREFIX
}

local tip1 = {
    type = "tips-and-tricks-item",
    name = PREFIX .. "tip1",
    order = "a",
    tag = string.format("[item=%s]", PREFIX .. "computation-core-mk1"),
    category = PREFIX .. "tips",
    is_title = true,
    trigger = {
        type = "research",
        technology = PREFIX .. "mk1-root"
    },
    starting_status = "unlocked",
}

local tip2 = {
    type = "tips-and-tricks-item",
    name = PREFIX .. "tip2",
    order = "b",
    category = PREFIX .. "tips",
    indent = 1,
    trigger = {
        type = "research",
        technology = PREFIX .. "mk1-root"
    },
    starting_status = "unlocked",
}

local tip3 = {
    type = "tips-and-tricks-item",
    name = PREFIX .. "tip3",
    order = "c",
    category = PREFIX .. "tips",
    indent = 1,
    trigger = {
        type = "research",
        technology = PREFIX .. "template-control-center-mk1"
    },
    starting_status = "unlocked",
}

local tip4 = {
    type = "tips-and-tricks-item",
    name = PREFIX .. "tip4",
    order = "c",
    category = PREFIX .. "tips",
    indent = 1,
    trigger = {
        type = "research",
        technology = PREFIX .. "template-computation-array-mk1"
    },
    starting_status = "unlocked",
}

local tip5 = {
    type = "tips-and-tricks-item",
    name = PREFIX .. "tip5",
    order = "d",
    category = PREFIX .. "tips",
    indent = 1,
    trigger = {
        type = "research",
        technology = PREFIX .. "template-computation-array-mk1"
    },
    starting_status = "unlocked",
}

local tip6 = {
    type = "tips-and-tricks-item",
    name = PREFIX .. "tip6",
    order = "e",
    category = PREFIX .. "tips",
    indent = 1,
    trigger = {
        type = "research",
        technology = PREFIX .. "template-computation-array-mk1"
    },
    starting_status = "unlocked",
}

local tip7 = {
    type = "tips-and-tricks-item",
    name = PREFIX .. "tip7",
    order = "f",
    category = PREFIX .. "tips",
    indent = 1,
    trigger = {
        type = "research",
        technology = PREFIX .. "template-computation-array-mk1"
    },
    starting_status = "unlocked",
}

local tip8 = {
    type = "tips-and-tricks-item",
    name = PREFIX .. "tip8",
    order = "g",
    category = PREFIX .. "tips",
    indent = 1,
    trigger = {
        type = "research",
        technology = PREFIX .. "template-computation-array-mk1"
    },
    starting_status = "unlocked",
}

local tip9 = {
    type = "tips-and-tricks-item",
    name = PREFIX .. "tip9",
    order = "h",
    category = PREFIX .. "tips",
    indent = 1,
    trigger = {
        type = "research",
        technology = PREFIX .. "template-computation-array-mk1"
    },
    starting_status = "unlocked",
}

local tip10 = {
    type = "tips-and-tricks-item",
    name = PREFIX .. "tip10",
    order = "i",
    category = PREFIX .. "tips",
    indent = 1,
    trigger = {
        type = "research",
        technology = PREFIX .. "virtualization-clusters"
    },
    starting_status = "unlocked",
}

local tip11 = {
    type = "tips-and-tricks-item",
    name = PREFIX .. "tip11",
    order = "j",
    category = PREFIX .. "tips",
    indent = 1,
    trigger = {
        type = "research",
        technology = PREFIX .. "virtualization-clusters"
    },
    starting_status = "unlocked",
}

local tip12 = {
    type = "tips-and-tricks-item",
    name = PREFIX .. "tip12",
    order = "k",
    category = PREFIX .. "tips",
    indent = 1,
    trigger = {
        type = "research",
        technology = PREFIX .. "template-access-interface-mk1"
    },
    starting_status = "unlocked",
}

local tip13 = {
    type = "tips-and-tricks-item",
    name = PREFIX .. "tip13",
    order = "l",
    category = PREFIX .. "tips",
    indent = 1,
    trigger = {
        type = "research",
        technology = PREFIX .. "template-access-interface-mk1"
    },
    starting_status = "unlocked",
}

data.extend{
    tips_category,
    tip1,
    tip2,
    tip3,
    tip4,
    tip5,
    tip6,
    tip7,
    tip8,
    tip9,
    tip10,
    tip11,
    tip12,
    tip13,
}
