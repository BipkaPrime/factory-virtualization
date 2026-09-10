--[[
Progression:

Stage I: MK1 (parts are completed "chronologically")
    Part I: introduction to template compilation, goal is to compile one production template
    1. Root research, everything starts from it.
        Requirments: quantum processor research
        Cost: All space age sciences except military and promethium (1 million?)
        Unlocks: intermediates mk1, tip 1 (basics), tip 2 (template definition)
    2. Template control center mk1.
        Requirments: root research
        Cost: same sciences as root, (500 k?)
        Unlocks: TCC mk1, tip3 (template control center).
    3. Template computation array mk1.
        Requirments: TCC mk1 tech.
        Cost: same sciences as root, (500 k?)
        Unlocks: TCA mk1, tips 4-9 (info related to template creation)
    4. Template item/fluid/energy io mk1, 3 different techs.
        Requirments: TCA mk1 tech
        Cost: same sciences as root, (500 k?)
        Unlocks: repsective port mk1
    5. Compile any template. (scripted trigger)
        Requirments: template item io mk1
        Cost: compile any template (scripted trigger)
        Unlocks: nothing, exists for learning purposes

    Part II: introduction to template execution, goal is to construct a working cluster
    1. Virtualization clusters
        Requirments: "compile any template" tech.
        Cost: same sciences as root, (2 mil?)
        Unlocks: tips 10-11
    2. Template access interface mk1.
        Requirments: "virtualization clusters" tech.
        Cost: same sciences as root, (500 k?)
        Unlocks: template access interface mk1. tips 12-13.
    3.  Cluster storage unit mk1, virtualization mainframe, cluster item/fluid/energy io: 5 techs in total
        Requirments: "virtualization clusters" tech.
        Cost: same sciences as root, (500 k?)
        Unlocks: respective building

    Part III: advanced cluster io mk1
    1. Inter-cluster bridge mk1, cluster overflow controller mk1
        Requirments: All simple cluster members mk1: vm, storage unit, cluster IOs.
        Cost: same sciences as root, (25 mil?)
        Unlocks: respective building

Stage II: MK2
    1. Mk2 root research.
        Requirments: All mk1 cluster buildings: vm, storage unit, cluster IOs, overflow controller, cluster bridge
        Cost: produce 250 mil blue circuits per hour (scripted trigger)
        Unlocks: intermediates mk2.
    2. Template buildings mk2: TCC, TAI, TCA
        Requirments: MK2 root
        Cost: same sciences as root, (100 mil?)
        Unlocks: respective building
    3. Template IO buildings mk2: template item/fluid/energy IO
        Requirments: MK2 root
        Cost: same sciences as root, (25 mil?)
        Unlocks: respective building
    4. Cluster members mk2: mainframe, storage unit
        Requirments: MK2 root
        Cost: same sciences as root, (100 mil?)
        Unlocks: respective building
    5. Cluster item/fluid/energy IOs mk2
        Requirments: MK2 root
        Cost: same sciences as root, (25 mil?)
        Unlocks: respective building
    6. Cluster advanced IOs mk2: cluster bridge, cluster overflow controller
        Requirments: MK2 root
        Cost: same sciences as root, (250 mil?)
        Unlocks: respective building

Stage III: MK3
    1. Mk3 root research.
        Requirments: all mk2 technologies
        Cost: produce 5 billion quantum processors per hour.
        Unlocks: all mk3 intermediates.
    3. Mk3 buildings

Win condition: final research.
    Requiements: all mk3 technologies
    Cost: produce N (3.6e12?) quantum processors per hour (scripted trigger)
    Unlocks: win screen
--]]

local iconpath = "__factory-virtualization__/graphics/technology/"

local research_ingredients = {
    {"automation-science-pack", 1},
    {"logistic-science-pack", 1},
    {"chemical-science-pack", 1},
    {"production-science-pack", 1},
    {"utility-science-pack", 1},
    {"space-science-pack", 1},
    {"metallurgic-science-pack", 1},
    {"electromagnetic-science-pack", 1},
    {"agricultural-science-pack", 1},
    {"cryogenic-science-pack", 1},
}

-------------------------------------------------------------------------------
-------------------------------- STAGE I: MK1 ---------------------------------
-------------------------------------------------------------------------------

local mk1_root = {
    type = "technology",
    name = PREFIX .. "mk1-root",
    icon = iconpath .. "mk1-root.png",
    icon_size = 256,
    order = PREFIX .. "a-a",
    unit = {count = 1e6, time = 60, ingredients = research_ingredients},
    prerequisites = {"quantum-processor"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "computation-core-mk1"},
        {type = "unlock-recipe", recipe = PREFIX .. "transmission-core-mk1"},
        {type = "unlock-recipe", recipe = PREFIX .. "storage-core-mk1"},
    },
}

local template_control_center_mk1 = {
    type = "technology",
    name = PREFIX .. "template-control-center-mk1",
    icon = iconpath .. "template-control-center-mk1.png",
    icon_size = 256,
    order = PREFIX .. "a-b",
    unit = {count = 5e5, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk1-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-control-center-mk1"},
    },
}

local template_computation_array_mk1 = {
    type = "technology",
    name = PREFIX .. "template-computation-array-mk1",
    icon = iconpath .. "template-computation-array-mk1.png",
    icon_size = 256,
    order = PREFIX .. "a-c",
    unit = {count = 5e5, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "template-control-center-mk1"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-computation-array-mk1"},
    },
}

local template_item_io_mk1 = {
    type = "technology",
    name = PREFIX .. "template-item-io-mk1",
    icon = iconpath .. "template-item-io-mk1.png",
    icon_size = 256,
    order = PREFIX .. "a-d",
    unit = {count = 5e5, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "template-computation-array-mk1"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-item-io-mk1"},
    },
}

local template_fluid_io_mk1 = {
    type = "technology",
    name = PREFIX .. "template-fluid-io-mk1",
    icon = iconpath .. "template-fluid-io-mk1.png",
    icon_size = 256,
    order = PREFIX .. "a-e",
    unit = {count = 5e5, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "template-computation-array-mk1"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-fluid-io-mk1"},
    },
}

local template_energy_io_mk1 = {
    type = "technology",
    name = PREFIX .. "template-energy-io-mk1",
    icon = iconpath .. "template-energy-io-mk1.png",
    icon_size = 256,
    order = PREFIX .. "a-f",
    unit = {count = 5e5, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "template-computation-array-mk1"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-energy-io-mk1"},
    },
}

local compile_any_template = {
    type = "technology",
    name = PREFIX .. "compile-any-template",
    icon = iconpath .. "compile-any-template.png",
    icon_size = 256,
    order = PREFIX .. "a-g",
    prerequisites = {
        PREFIX .. "template-item-io-mk1",
        PREFIX .. "template-fluid-io-mk1",
        PREFIX .. "template-energy-io-mk1",
    },
    research_trigger = {type = "scripted"},
}

local virtualization_clusters = {
    type = "technology",
    name = PREFIX .. "virtualization-clusters",
    icon = iconpath .. "virtualization-clusters.png",
    icon_size = 256,
    order = PREFIX .. "a-h",
    unit = {count = 2e6, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "compile-any-template"},
}

local template_access_interface_mk1 = {
    type = "technology",
    name = PREFIX .. "template-access-interface-mk1",
    icon = iconpath .. "template-access-interface-mk1.png",
    icon_size = 256,
    order = PREFIX .. "a-i",
    unit = {count = 5e5, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "virtualization-clusters"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-access-interface-mk1"},
    },
}

local virtualization_mainframe_mk1 = {
    type = "technology",
    name = PREFIX .. "virtualization-mainframe-mk1",
    icon = iconpath .. "virtualization-mainframe-mk1.png",
    icon_size = 256,
    order = PREFIX .. "a-j",
    unit = {count = 5e5, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "virtualization-clusters"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "virtualization-mainframe-mk1"},
    },
}

local cluster_storage_unit_mk1 = {
    type = "technology",
    name = PREFIX .. "cluster-storage-unit-mk1",
    icon = iconpath .. "cluster-storage-unit-mk1.png",
    icon_size = 256,
    order = PREFIX .. "a-k",
    unit = {count = 5e5, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "virtualization-clusters"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "cluster-storage-unit-mk1"},
    },
}

local cluster_item_io_mk1 = {
    type = "technology",
    name = PREFIX .. "cluster-item-io-mk1",
    icon = iconpath .. "cluster-item-io-mk1.png",
    icon_size = 256,
    order = PREFIX .. "a-l",
    unit = {count = 5e5, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "virtualization-clusters"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "cluster-item-io-mk1"},
    },
}

local cluster_fluid_io_mk1 = {
    type = "technology",
    name = PREFIX .. "cluster-fluid-io-mk1",
    icon = iconpath .. "cluster-fluid-io-mk1.png",
    icon_size = 256,
    order = PREFIX .. "a-m",
    unit = {count = 5e5, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "virtualization-clusters"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "cluster-fluid-io-mk1"},
    },
}

local cluster_energy_io_mk1 = {
    type = "technology",
    name = PREFIX .. "cluster-energy-io-mk1",
    icon = iconpath .. "cluster-energy-io-mk1.png",
    icon_size = 256,
    order = PREFIX .. "a-n",
    unit = {count = 5e5, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "virtualization-clusters"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "cluster-energy-io-mk1"},
    },
}

local inter_cluster_bridge_mk1 = {
    type = "technology",
    name = PREFIX .. "inter-cluster-bridge-mk1",
    icon = iconpath .. "inter-cluster-bridge-mk1.png",
    icon_size = 256,
    order = PREFIX .. "a-o",
    unit = {count = 2.5e7, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "virtualization-clusters"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "inter-cluster-bridge-mk1"},
    },
}

local cluster_overflow_controller_mk1 = {
    type = "technology",
    name = PREFIX .. "cluster-overflow-controller-mk1",
    icon = iconpath .. "cluster-overflow-controller-mk1.png",
    icon_size = 256,
    order = PREFIX .. "a-p",
    unit = {count = 2.5e7, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "virtualization-clusters"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "cluster-overflow-controller-mk1"},
    },
}

data.extend{
    mk1_root,
    template_control_center_mk1,
    template_computation_array_mk1,
    template_item_io_mk1,
    template_fluid_io_mk1,
    template_energy_io_mk1,
    compile_any_template,
    virtualization_clusters,
    template_access_interface_mk1,
    virtualization_mainframe_mk1,
    cluster_storage_unit_mk1,
    cluster_item_io_mk1,
    cluster_fluid_io_mk1,
    cluster_energy_io_mk1,
    inter_cluster_bridge_mk1,
    cluster_overflow_controller_mk1,
}

-------------------------------------------------------------------------------
-------------------------------- STAGE II: MK2 --------------------------------
-------------------------------------------------------------------------------

local mk2_root = {
    type = "technology",
    name = PREFIX .. "mk2-root",
    icon = iconpath .. "mk2-root.png",
    icon_size = 256,
    order = PREFIX .. "b-a",
    prerequisites = {
        PREFIX .. "template-access-interface-mk1",
        PREFIX .. "virtualization-mainframe-mk1",
        PREFIX .. "cluster-storage-unit-mk1",
        PREFIX .. "cluster-item-io-mk1",
        PREFIX .. "cluster-fluid-io-mk1",
        PREFIX .. "cluster-energy-io-mk1",
        PREFIX .. "inter-cluster-bridge-mk1",
        PREFIX .. "cluster-overflow-controller-mk1",
    },
    research_trigger = {type = "scripted"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "computation-core-mk2"},
        {type = "unlock-recipe", recipe = PREFIX .. "transmission-core-mk2"},
        {type = "unlock-recipe", recipe = PREFIX .. "storage-core-mk2"},
    },
}

local template_control_center_mk2 = {
    type = "technology",
    name = PREFIX .. "template-control-center-mk2",
    icon = iconpath .. "template-control-center-mk2.png",
    icon_size = 256,
    order = PREFIX .. "b-b",
    unit = {count = 1e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk2-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-control-center-mk2"},
    },
}

local template_computation_array_mk2 = {
    type = "technology",
    name = PREFIX .. "template-computation-array-mk2",
    icon = iconpath .. "template-computation-array-mk2.png",
    icon_size = 256,
    order = PREFIX .. "b-c",
    unit = {count = 1e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk2-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-computation-array-mk2"},
    },
}

local template_access_interface_mk2 = {
    type = "technology",
    name = PREFIX .. "template-access-interface-mk2",
    icon = iconpath .. "template-access-interface-mk2.png",
    icon_size = 256,
    order = PREFIX .. "b-d",
    unit = {count = 1e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk2-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-access-interface-mk2"},
    },
}

local template_item_io_mk2 = {
    type = "technology",
    name = PREFIX .. "template-item-io-mk2",
    icon = iconpath .. "template-item-io-mk2.png",
    icon_size = 256,
    order = PREFIX .. "b-e",
    unit = {count = 2.5e7, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk2-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-item-io-mk2"},
    },
}

local template_fluid_io_mk2 = {
    type = "technology",
    name = PREFIX .. "template-fluid-io-mk2",
    icon = iconpath .. "template-fluid-io-mk2.png",
    icon_size = 256,
    order = PREFIX .. "b-f",
    unit = {count = 2.5e7, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk2-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-fluid-io-mk2"},
    },
}

local template_energy_io_mk2 = {
    type = "technology",
    name = PREFIX .. "template-energy-io-mk2",
    icon = iconpath .. "template-energy-io-mk2.png",
    icon_size = 256,
    order = PREFIX .. "b-g",
    unit = {count = 2.5e7, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk2-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-energy-io-mk2"},
    },
}

local virtualization_mainframe_mk2 = {
    type = "technology",
    name = PREFIX .. "virtualization-mainframe-mk2",
    icon = iconpath .. "virtualization-mainframe-mk2.png",
    icon_size = 256,
    order = PREFIX .. "b-h",
    unit = {count = 1e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk2-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "virtualization-mainframe-mk2"},
    },
}

local cluster_storage_unit_mk2 = {
    type = "technology",
    name = PREFIX .. "cluster-storage-unit-mk2",
    icon = iconpath .. "cluster-storage-unit-mk2.png",
    icon_size = 256,
    order = PREFIX .. "b-i",
    unit = {count = 1e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk2-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "cluster-storage-unit-mk2"},
    },
}

local cluster_item_io_mk2 = {
    type = "technology",
    name = PREFIX .. "cluster-item-io-mk2",
    icon = iconpath .. "cluster-item-io-mk2.png",
    icon_size = 256,
    order = PREFIX .. "b-j",
    unit = {count = 2.5e7, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk2-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "cluster-item-io-mk2"},
    },
}

local cluster_fluid_io_mk2 = {
    type = "technology",
    name = PREFIX .. "cluster-fluid-io-mk2",
    icon = iconpath .. "cluster-fluid-io-mk2.png",
    icon_size = 256,
    order = PREFIX .. "b-k",
    unit = {count = 2.5e7, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk2-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "cluster-fluid-io-mk2"},
    },
}

local cluster_energy_io_mk2 = {
    type = "technology",
    name = PREFIX .. "cluster-energy-io-mk2",
    icon = iconpath .. "cluster-energy-io-mk2.png",
    icon_size = 256,
    order = PREFIX .. "b-l",
    unit = {count = 2.5e7, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk2-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "cluster-energy-io-mk2"},
    },
}

local inter_cluster_bridge_mk2 = {
    type = "technology",
    name = PREFIX .. "inter-cluster-bridge-mk2",
    icon = iconpath .. "inter-cluster-bridge-mk2.png",
    icon_size = 256,
    order = PREFIX .. "b-m",
    unit = {count = 2.5e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk2-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "inter-cluster-bridge-mk2"},
    },
}

local cluster_overflow_controller_mk2 = {
    type = "technology",
    name = PREFIX .. "cluster-overflow-controller-mk2",
    icon = iconpath .. "cluster-overflow-controller-mk2.png",
    icon_size = 256,
    order = PREFIX .. "b-n",
    unit = {count = 2.5e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk2-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "cluster-overflow-controller-mk2"},
    },
}

data.extend{
    mk2_root,
    template_control_center_mk2,
    template_computation_array_mk2,
    template_access_interface_mk2,
    template_item_io_mk2,
    template_fluid_io_mk2,
    template_energy_io_mk2,
    virtualization_mainframe_mk2,
    cluster_storage_unit_mk2,
    cluster_item_io_mk2,
    cluster_fluid_io_mk2,
    cluster_energy_io_mk2,
    inter_cluster_bridge_mk2,
    cluster_overflow_controller_mk2,
}

-------------------------------------------------------------------------------
------------------------------- STAGE III: MK3 --------------------------------
-------------------------------------------------------------------------------

local mk3_root = {
    type = "technology",
    name = PREFIX .. "mk3-root",
    icon = iconpath .. "mk3-root.png",
    icon_size = 256,
    order = PREFIX .. "c-a",
    prerequisites = {
        PREFIX .. "template-control-center-mk2",
        PREFIX .. "template-computation-array-mk2",
        PREFIX .. "template-access-interface-mk2",
        PREFIX .. "template-item-io-mk2",
        PREFIX .. "template-fluid-io-mk2",
        PREFIX .. "template-energy-io-mk2",
        PREFIX .. "virtualization-mainframe-mk2",
        PREFIX .. "cluster-storage-unit-mk2",
        PREFIX .. "cluster-item-io-mk2",
        PREFIX .. "cluster-fluid-io-mk2",
        PREFIX .. "cluster-energy-io-mk2",
        PREFIX .. "inter-cluster-bridge-mk2",
        PREFIX .. "cluster-overflow-controller-mk2",
    },
    research_trigger = {type = "scripted"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "computation-core-mk3"},
        {type = "unlock-recipe", recipe = PREFIX .. "transmission-core-mk3"},
        {type = "unlock-recipe", recipe = PREFIX .. "storage-core-mk3"},
    },
}

local template_control_center_mk3 = {
    type = "technology",
    name = PREFIX .. "template-control-center-mk3",
    icon = iconpath .. "template-control-center-mk3.png",
    icon_size = 256,
    order = PREFIX .. "c-b",
    unit = {count = 5e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk3-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-control-center-mk3"},
    },
}

local template_computation_array_mk3 = {
    type = "technology",
    name = PREFIX .. "template-computation-array-mk3",
    icon = iconpath .. "template-computation-array-mk3.png",
    icon_size = 256,
    order = PREFIX .. "c-c",
    unit = {count = 5e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk3-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-computation-array-mk3"},
    },
}

local template_access_interface_mk3 = {
    type = "technology",
    name = PREFIX .. "template-access-interface-mk3",
    icon = iconpath .. "template-access-interface-mk3.png",
    icon_size = 256,
    order = PREFIX .. "c-d",
    unit = {count = 5e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk3-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-access-interface-mk3"},
    },
}

local template_item_io_mk3 = {
    type = "technology",
    name = PREFIX .. "template-item-io-mk3",
    icon = iconpath .. "template-item-io-mk3.png",
    icon_size = 256,
    order = PREFIX .. "c-e",
    unit = {count = 1e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk3-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-item-io-mk3"},
    },
}

local template_fluid_io_mk3 = {
    type = "technology",
    name = PREFIX .. "template-fluid-io-mk3",
    icon = iconpath .. "template-fluid-io-mk3.png",
    icon_size = 256,
    order = PREFIX .. "c-f",
    unit = {count = 1e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk3-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-fluid-io-mk3"},
    },
}

local template_energy_io_mk3 = {
    type = "technology",
    name = PREFIX .. "template-energy-io-mk3",
    icon = iconpath .. "template-energy-io-mk3.png",
    icon_size = 256,
    order = PREFIX .. "c-g",
    unit = {count = 1e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk3-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "template-energy-io-mk3"},
    },
}

local virtualization_mainframe_mk3 = {
    type = "technology",
    name = PREFIX .. "virtualization-mainframe-mk3",
    icon = iconpath .. "virtualization-mainframe-mk3.png",
    icon_size = 256,
    order = PREFIX .. "c-h",
    unit = {count = 5e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk3-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "virtualization-mainframe-mk3"},
    },
}

local cluster_storage_unit_mk3 = {
    type = "technology",
    name = PREFIX .. "cluster-storage-unit-mk3",
    icon = iconpath .. "cluster-storage-unit-mk3.png",
    icon_size = 256,
    order = PREFIX .. "c-i",
    unit = {count = 5e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk3-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "cluster-storage-unit-mk3"},
    },
}

local cluster_item_io_mk3 = {
    type = "technology",
    name = PREFIX .. "cluster-item-io-mk3",
    icon = iconpath .. "cluster-item-io-mk3.png",
    icon_size = 256,
    order = PREFIX .. "c-j",
    unit = {count = 1e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk3-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "cluster-item-io-mk3"},
    },
}

local cluster_fluid_io_mk3 = {
    type = "technology",
    name = PREFIX .. "cluster-fluid-io-mk3",
    icon = iconpath .. "cluster-fluid-io-mk3.png",
    icon_size = 256,
    order = PREFIX .. "c-k",
    unit = {count = 1e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk3-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "cluster-fluid-io-mk3"},
    },
}

local cluster_energy_io_mk3 = {
    type = "technology",
    name = PREFIX .. "cluster-energy-io-mk3",
    icon = iconpath .. "cluster-energy-io-mk3.png",
    icon_size = 256,
    order = PREFIX .. "c-l",
    unit = {count = 1e8, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk3-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "cluster-energy-io-mk3"},
    },
}

local inter_cluster_bridge_mk3 = {
    type = "technology",
    name = PREFIX .. "inter-cluster-bridge-mk3",
    icon = iconpath .. "inter-cluster-bridge-mk3.png",
    icon_size = 256,
    order = PREFIX .. "c-m",
    unit = {count = 1e9, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk3-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "inter-cluster-bridge-mk3"},
    },
}

local cluster_overflow_controller_mk3 = {
    type = "technology",
    name = PREFIX .. "cluster-overflow-controller-mk3",
    icon = iconpath .. "cluster-overflow-controller-mk3.png",
    icon_size = 256,
    order = PREFIX .. "c-n",
    unit = {count = 1e9, time = 60, ingredients = research_ingredients},
    prerequisites = {PREFIX .. "mk3-root"},
    effects = {
        {type = "unlock-recipe", recipe = PREFIX .. "cluster-overflow-controller-mk3"},
    },
}

local victory = {
    type = "technology",
    name = PREFIX .. "victory",
    icon = iconpath .. "victory.png",
    icon_size = 256,
    order = PREFIX .. "d",
    prerequisites = {
        PREFIX .. "template-control-center-mk3",
        PREFIX .. "template-computation-array-mk3",
        PREFIX .. "template-access-interface-mk3",
        PREFIX .. "template-item-io-mk3",
        PREFIX .. "template-fluid-io-mk3",
        PREFIX .. "template-energy-io-mk3",
        PREFIX .. "virtualization-mainframe-mk3",
        PREFIX .. "cluster-storage-unit-mk3",
        PREFIX .. "cluster-item-io-mk3",
        PREFIX .. "cluster-fluid-io-mk3",
        PREFIX .. "cluster-energy-io-mk3",
        PREFIX .. "inter-cluster-bridge-mk3",
        PREFIX .. "cluster-overflow-controller-mk3",
    },
    research_trigger = {type = "scripted"},
}

data.extend{
    mk3_root,
    template_control_center_mk3,
    template_computation_array_mk3,
    template_access_interface_mk3,
    template_item_io_mk3,
    template_fluid_io_mk3,
    template_energy_io_mk3,
    virtualization_mainframe_mk3,
    cluster_storage_unit_mk3,
    cluster_item_io_mk3,
    cluster_fluid_io_mk3,
    cluster_energy_io_mk3,
    inter_cluster_bridge_mk3,
    cluster_overflow_controller_mk3,
    victory,
}