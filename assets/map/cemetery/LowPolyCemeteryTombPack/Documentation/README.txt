Low Poly Cemetery Tomb Pack
Maciej EmacEArt
================================================================

HOW TO ADD IT TO YOUR PROJECT
  Copy the contents of this pack into your Godot project (into res://).
  That is all -- the pack is self-contained and does not require any
  plugins or add-ons.

WHAT IS WHERE
  Prefabs/        ready-to-use object scenes (.scn) -- these are what
                  you instance in your own scenes, grouped by type:
                  Tomb/Entrances  crypt fronts with a doorway, in three
                                  finishes (clean stone, mossy, white
                                  trim) and three size classes A, B, C;
                  Tomb/Niches     closed burial niche blocks in the same
                                  three finishes and size classes -- set
                                  them side by side to build a
                                  columbarium wall;
                  Tomb/Segments   plain vertical wall segments, clean and
                                  mossy, for stacking your own tombs out
                                  of an entrance, segments and a roof;
                  Tomb/Roofs      roof caps that finish a stacked tomb;
                  Tomb/Ruined     collapsed and overgrown tombs;
                  Tomb/Doors      separate doors that fit the entrances;
                  Tomb/Covers     separate slabs that close a niche;
                  Tomb/Decor      chains, a handle, knockers and a wall
                                  ornament to dress a facade;
                  Tomb/Composite  one whole tomb already assembled from
                                  the modules, as a worked example.
                  Every object comes with a static collision body.
  Meshes/         source FBX files and the meshes extracted from them
                  (three detail levels per model), the demo terrain and
                  the grass field
  Materials/      the shared pack material lives in the root as
                  EA_Shared.material; here are the terrain, grass and
                  sky materials used by the demo
  Textures/       the one colour palette every object uses, the ground
                  texture and the grass textures
  Shaders/        ground, grass wind and skybox shaders (included so the
                  demo scene runs as shown)
  Scenes/         Demo.tscn -- a necropolis at night: an avenue of crypts
                  leading to a tall stacked tomb, niche walls closing the
                  sides, ruined tombs in the old quarter;
                  Showroom.tscn -- every object laid out in rows
  Documentation/  this file, license, contents list

HOW TO USE
  Drag a .scn file from Prefabs/ into your scene, or use
  "Instantiate Child Scene". Every object already comes with its
  mesh, material, collision and detail levels.

BUILDING YOUR OWN TOMB OUT OF THE MODULES
  An entrance, one or more vertical segments and a roof stack into a
  tomb of any height: place the entrance on the ground, put a segment
  directly on top of it, repeat, and finish with a roof. The modules
  share one footprint per size class (A, B, C), so pieces of the same
  class always line up. Tomb/Composite shows one finished example you
  can take apart.

CHANGING THE LOOK OF THE WHOLE PACK
  Every object is painted from one palette texture
  (Textures/T_colorPalette2048_CGT.png) through one material
  (EA_Shared.material in the root). Point that material at a repainted
  copy of the palette and every object changes at once.

ART STYLE
  Handcrafted low poly, flat colours from a palette texture, no
  normal maps on the objects. Built for stylized games in first-person,
  third-person and top-down views.

TESTED ON
  Godot 4.7.1 (Forward+)

LICENSE
  EmacEArt Asset License - Free for personal and commercial use, but
  resale or redistribution of the assets as standalone files or asset
  packs is prohibited. No credit is required, though it is always
  welcome. See LICENSE.txt in this folder.

CONTACT
  Website: emaceart.dev
  Discord: https://discord.com/invite/ctXaf5Ftqw
  itch.io: https://emaceart.itch.io

================================================================
