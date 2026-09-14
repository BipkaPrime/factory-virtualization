# Factory Virtualization
Factory Virtualization adds an entirely new approach to production and logistics
allowing your Factory to grow past all known limits. Discover a way to compile
your production lines into production templates. Replace millions of physical
machines with virtualization clusters executing your templates for real production.
Clusters are assembled from specialized buildings. Add more crafting power by
building more virtualization mainframes; add more storage by building more storage
units. Complete the mod by building a digital empire that will make the biggest
Space Age megabases look like simple starter bases. Progression starts on Aquilo.
You can add the mod to an existing save (don't forget to back it up).

## Development stage
This is the alpha version of the mod, and it hasn't been playtested yet.
That said, it **works properly 99.9%** of the time during my testing.
I wrote every single line of the script myself and double-checked everything,
so I'm pretty confident it's not going to break itself apart.
I haven't run into any data-breaking issues for a long time
(these can be really dangerous). However, **it's theoretically possible**
for something to go terribly wrong. I highly suggest enabling autosaves.
Also, creating a manual backup every 5-10 hours or so definitely wouldn't hurt.

## Solving the UPS problem
When you are building a large factory, you inevitably end up with many copies of
the same production line doing exactly the same thing. Every single entity in every
single production line has to be updated individually. Every single tick. Factorio
is incredibly well-optimized and can handle tens of thousands of working entities
without causing problems with UPS. However, in the process of expanding the factory,
you will eventually reach a point when your UPS drops below 60 and the game becomes
unpleasant to play. At this point, most players abandon their factories.

But it does not have to be this way! Factory Virtualization is the solution to this
problem. It introduces three optimization concepts that allow your factory to grow
almost indefinitely:
1. Take your production line and **compile** it into a mathematical model (a
**production template**) with defined inputs and outputs. Now you can **execute**
this template in O(1) time, regardless of the number of entities in your production
line.
2. Templates are executed in **virtualization clusters**. Clusters are capable of
executing an assigned template multiple times in parallel. This takes exactly the
same amount of processing time as executing a single template. You can think of
this as having several copies of your production line working inside a single cluster.
3. Clusters execute the assigned template once every 60 ticks (1 second), which is
obviously more efficient than doing it every tick. _Execution is distributed evenly
across ticks to eliminate lag spikes._

## Production templates
A template is a mathematical model of a production chain containing four key
components:
1. Inputs — resources consumed per second.
2. Outputs — products generated per second.
3. Construction cost — materials required to "construct" the template (think of it
as a capital investment: machines, inserters, belts that would normally form the
physical line).
4. Virtualization overhead — additional electrical power consumed per second.

## Virtualization surfaces
Specialized surfaces used for compilation of your production lines into production
templates. You should think of a **vsurface** as a virtual sandbox. Any production
chain can be constructed here for free. Following is performed automatically:
ghosts are revived, deconstruction and update requests fulfilled, item requests
are satisfied. Just place your blueprints and they will be constructed automatically.

Can be generated empty (with lab tiles) or using a **mapgen** of any planet
yielding a vsurface with resources. Size of generated surface can vary from 1x1
to 1024x1024 tiles. Creation of larger surfaces and surfaces with resources
requires significantly more infrastructure and research.
![vsurfaces example](images/vsurfaces-example.png)

To compile a new template, your production chain must be constructed on a
virtualization surface and then compilation of that surface should be started.
When the compilation process successfully finishes, a compiled template
will be created.

To define inputs and outputs of your template, **template item/fluid/energy IOs**
are used. These buildings only work on virtualization surfaces and have two modes
of operation:
1. Source mode — port materializes resources and records them as template inputs.
2. Sink mode — port destroys resources and records them as template outputs.

![Template io ports](images/template-io.png)

## Template validation
To prevent various exploits of template mechanic, the system performs periodic
validation checks on the compiling vsurface. It verifies the material balance
for every resource. There are four components considered:
1. Inputs — resources spawned by IO ports during compilation.
2. Outputs — resources destroyed by IO ports during compilation.
3. Produced — resources produced on this vsurface (production statistics).
4. Consumed — resources consumed on this vsurface (production statistics)

Validation is passed if **Input + Produced == Output + Consumed**. A relative
deviation of less than 1% is considered acceptable.
![validation example](images/template-validation.png)

## Virtualization infrastructure
Compilation of production templates is not an easy task and requires serious
infrastructure, which has to be built on Aquilo, where extreme cold provides
the necessary cooling for quantum processors.

**Template control center** is the heart of your digital empire. The system
cannot work without it. You only need one. It is required for:
1. Creating and maintaining virtualization surfaces.
2. Compiling those surfaces into production templates.
3. Granting access to compiled templates.

![Template control centers](images/control-center.png)

**Template computation arrays** are needed to produce **computation**, which
is required to sustain the existance of virtualization surfaces.
![Template computation arrays](images/computation-array.png)

**Template access interfaces** are needed to provide access to compiled
templates to virtualization clusters.
![Template access interfaces](images/access-interface.png)

## Virtualization clusters
Clusters are simulated factories that produce resources by executing a production
template. Clusters can consume and produce items, fluids, and electric energy.
Clusters are formed from specialized buildings with unique roles:

**Virtualization mainframes** provide **crafting power** to the cluster allowing
it to execute more crafts in parallel. However, template construction materials
have to be provided before mainframe becomes operational and contributes to
the cluster.
![Virtualization mainframes](images/vmainframe.png)

**Cluster storage units** increase the size of internal buffers of the cluster.
![Cluster storage units](images/storage-unit.png)

**Cluster item/fluid/energy IOs** are used to transfer resources between
the physical world and internal buffers of the cluster.
![Cluster IOs](images/cluster-io.png)

**Inter-cluster bridges** are used to transfer resources directly from the
output of one cluster to the input of another. Can work with items, fluids
or energy. Transfer speed is incredibly high. A normal quality MK1 bridge
can transfer 1M items/s; 10M fluid/s; 1TW of energy. 
![Inter-cluster bridges](images/cluster-bridge.png)

**Cluster overflow controllers** are used to void overflow in the output
buffer of the cluster. Have a configurable overflow threshold and incredibly
high throughput.
![Cluster overflow controllers](images/overflow-controller.png)

## Cluster efficiency
Energy consumption of a cluster depends not only on the template it is
executing, but also on how spread out its members are. The
**decentralization loss** is an additional energy cost that increases
with the distance between cluster members. It is applied multiplicatively
to the base energy cost of template execution. The loss is proportional
to the average squared distance from the position of cluster members to
cluster center. The center is calculated as the weighted average of all
member positions. The loss does not scale with the number of members — only
their distribution matters. This encourages you to build compact clusters.

## Quality of life
Factory Virtualization adds several unique and complicated mechanics.
To aid you in the construction of your digital empire, it also adds the
following quality of life features:

**Custom entity configuration alerts**. Most entities in the mod have to
be properly configured to work. Also they may have other working conditions.
Alerts allow you to instantly see which entities are not working.
![alerts example](images/alerts-example.png)

Almost **50 custom entity statuses** that allow you to understand exactly
why entity is not working.

Convenient **custom GUI windows** with too many features to list them all
here. Here are some of the features related to **clusters** tab of the
main dashboard:
1. **Cluster members** section allows you to see total/operational counts
for each member type in a table. For each type there is also
a button that moves your camera to non-operational member of that type.
2. Cluster performance section allows you to see how well your cluster is
performing. 
3. Input and output buffer details. Bar colors are used to display bottlenecks.

![clusters gui example](images/clusters-gui.png)

**13 tips and tricks** with additional mod-related information you can
check in-game.

## Compatability
This mod should be compatible with multiplayer.

This mod should be compatible with any mod except:
1. Any mod that messes with forces of players. Everything related to
vsurfaces, clusters, etc. is bound to "player" force. If your force is
changed to something else, Factory Virtualization will not work properly.
So, no PVP team on team action.
2. Any mod that messes with surfaces too much. Clusters are bound to surfaces
on creation. If surface is deleted, cluster is deleted too.

## Credits
**PreLeyZero** — [Exotic Industries](https://mods.factorio.com/mod/exotic-industries) (GNU GPLv3). Almost all sprites that I'm using in my mod were derived (tweaked, combined and recolored) from this project. In my opinion, they look awesome and fit the theme of my mod.

**raiguard** — [Krastorio 2](https://mods.factorio.com/mod/Krastorio2) (GNU LGPLv3).
Sprites of **Template access interfaces** were derived (tweaked and recolored) from the texture of **Intergalactic transciever** in this project. This sprite is also great
and fits the building perfectly.

## Future plans


## Support the project
