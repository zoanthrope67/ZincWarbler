# Making a Low Poly Model in Blender for Zinc Warbler

This guide covers making a low poly model in Blender 5.3.0, texturing it,
exporting it, and putting it in the game in place of the placeholder player or
enemy. It is written for this project's scenes and its camera.

The steps were checked by exporting test models from Blender 5.3.0 and
importing them into a copy of this project in Godot 4.7.2. That confirmed the
facing direction, the material type, the enemy fade-in, and a looping part
animation that autoplays.

---

## 1. What the game needs

| Thing | What to do | Why |
|---|---|---|
| Size | 1 Blender unit = 1 m. Player and normal enemies fit in a 2 x 2 m footprint; Angry Greg fits in 4 x 4 m | Matches the hitboxes and docs/SPEC.md |
| Centre | The middle of the body sits at the world origin (0, 0, 0) | The node's origin is 1 m above the floor, at the centre of its hitbox sphere |
| Floor | The bottom of the model sits at Z = -1 m | The floor is 1 m below the node's origin (`Gameplay.PLANE_HEIGHT`) |
| Front | The model faces **-Y** in Blender, so it looks at you in Front view (Numpad 1) | It becomes +Z in Godot, which is the model's front in the game |
| Triangles | Normal enemies: aim for under 500. Player and bosses: under 2000 | Hundreds of enemies can be on screen, and the game must run on low spec machines |
| Materials | One material per model, using a Principled BSDF with an Image Texture on Base Color | It imports as a StandardMaterial3D, which the enemy fade-in needs |
| Textures | Small, 256 x 256 or less. A colour palette of 32 x 32 or 64 x 64 is plenty | Small textures load fast and use little memory |

**What the player actually sees.** The camera looks straight down and shows
about 40 m of the arena from top to bottom of the screen. A 2 m enemy is only
about 50 pixels tall on a 1080p screen. Only the **top-down silhouette** and
**strong colours** read in the game. Check your model in Top view (Numpad 7)
often, and don't spend triangles on detail underneath or on the sides.

The arena has one directional light with no shadows. Ambient light and
reflections come from the sky image (`gfx/sky/`), so shapes read through colour
more than shading.

The camera looks down on the dark part of the sky, so a very metallic, shiny
material (Metallic near 1, low Roughness) mostly reflects dark blue. For the
model's own colour to show, keep Metallic low (0 to 0.3) and Roughness around 0.4.

**Palette textures** must not be compressed by Godot. Godot's default
compression blends neighbouring pixels, so palette colours come out wrong (for
example, orange turning grey-green). The import setting in
[section 6](#6-put-it-in-the-game-godot) avoids this.

---

## 2. Set up the Blender file

1. **File > New > General**. Delete the default cube, camera and light
   (select them, then **X > Delete**).
2. Check the units: **Scene Properties** (cone icon) **> Units**. Use
   Unit System **Metric** and Unit Scale **1.0** (the defaults).
3. **Add a hitbox reference** so you can see the size to fill:
   - **Add > Mesh > UV Sphere**. In the "Add UV Sphere" panel (bottom left),
     set Radius to **1 m**, or **2 m** for a boss. Leave Location at 0, 0, 0.
   - Rename it `REF_hitbox` (double-click its name in the Outliner).
   - In **Object Properties > Viewport Display**, set **Display As: Wire**.
   - It is only a guide. It won't be exported, because export uses
     "Selected Objects" (section 5).
4. Save the file (**Ctrl+S**), for example as `chaser.blend`. See
   [Where to keep files](#8-where-to-keep-files) below.

---

## 3. Model it (low poly)

Start from a primitive with few sides and shape it in Edit Mode (**Tab**).

- **Add > Mesh > Cylinder / UV Sphere / Cube.** In the "Add" panel, lower the
  Vertices or Segments (6 to 8 is a good low poly look).
- Useful Edit Mode tools:
  - **E** extrudes selected faces.
  - **I** insets faces.
  - **Ctrl+R** adds a loop cut.
  - **G / R / S** move, rotate and scale. Follow them with **X / Y / Z** to
    lock to an axis.
  - Use **1 / 2 / 3** (top row) to switch between vertex, edge and face select.
- **Symmetry:** model one half and add a **Mirror** modifier
  (**Modifier Properties > Add Modifier > Generate > Mirror**, axis **X**).
  It is applied on export.
- **Flat shading** gives the faceted low poly look. In Object Mode, use
  **Object > Shade Flat**.
- **Triangle count:** in the viewport, turn on **Overlays** (the
  two-circles dropdown at the top right) **> Statistics**. Check the
  "Triangles" line.
- **Several parts:** keep them as separate objects while modelling. Before
  export, select them all and press **Ctrl+J** to join them into one object.
  One object with one material is the cheapest to draw. **Don't join parts
  that will be animated**; see [section 7](#7-animating-parts).

**Before exporting**, in Object Mode, select the model and press
**Ctrl+A > All Transforms**. This bakes the size and rotation into the mesh, so
it arrives in Godot at exactly the size you see.

For a part that will be animated, use **Ctrl+A > Rotation & Scale** instead.
All Transforms also applies location: it moves the part's origin back to the
world centre and loses its pivot.

---

## 4. Texture it

Two ways. **A (palette)** is recommended for low poly: it is quick, the model
uses one tiny texture, and colours are easy to change later.

### A. Colour palette texture (recommended)

1. **Make the palette image** in any paint program (Krita, GIMP, Aseprite…).
   - Use a small PNG such as **32 x 32**, filled with blocks of flat colour.
     For example, a 4 x 4 grid of 8 x 8 pixel squares gives 16 colours.
   - Save it next to the `.blend` file, e.g. `chaser_palette.png`.
2. **Make the material.** Select the model and switch to the **Shading**
   workspace (tabs at the top of the window).
   - In the node editor, click **New** to make a material. You get a
     Principled BSDF.
   - **Shift+A > Texture > Image Texture**, then click **Open** on the new
     node and choose the palette PNG.
   - Drag the Image Texture's **Color** output to the Principled BSDF's
     **Base Color** input.
   - On the Image Texture node, change **Linear** to **Closest**. The
     colours then stay crisp, and Godot keeps this setting. The test import
     came in with Nearest filtering.
3. **Put faces on colours.** Switch to the **UV Editing** workspace.
   - **Tab** into Edit Mode, press **3** for face select, and select every
     face that should be one colour (**L** selects a linked part under the
     mouse).
   - Press **U > Smart UV Project**, then **OK**.
   - In the UV editor (left), press **S 0 Enter**. This squashes those faces'
     UVs to a single point, so they all get exactly one colour.
   - Press **G** and move the point into the middle of a colour square on the
     palette. Keep it away from the edges of the square.
   - Repeat for each colour.
4. To recolour later, change the faces' UVs or edit the palette PNG. Then
   export again.

### B. Painted texture

For more detail, such as markings or a face:

1. **UV unwrap** the whole model in the **UV Editing** workspace: select all
   (**A**), then **U > Smart UV Project**.
2. Make the material as in A2, but in the Image Texture node click **New**
   instead of Open. Make the image **256 x 256** or smaller.
3. Paint in the **Texture Paint** workspace. When finished, save the image:
   **Image > Save As** in the image editor. It is lost otherwise.
4. Painted textures need different import settings in Godot from palettes.
   See "Palette textures vs painted textures" in section 6.

### Material rules (both ways)

- Only the Principled BSDF with an **Image Texture** (or a plain Base Color)
  exports. Procedural nodes don't: noise, colour ramps and mix nodes are
  dropped by the glTF exporter.
- Leave Alpha at 1. The enemy fade-in makes the model see-through on its own.

---

## 5. Export from Blender

1. In Object Mode, select only the model, not `REF_hitbox`.
2. **File > Export > glTF 2.0 (.glb/.gltf)**.
3. In the settings on the right:

| Section | Setting | Value |
|---|---|---|
| (top) | Format | **glTF Binary (.glb)**: one file with the texture inside |
| Include > Limit to | Selected Objects | **On** |
| Include | Cameras, Punctual Lights | Off (the defaults) |
| Transform | +Y Up | **On** (the default) |
| Data > Mesh | Apply Modifiers | **On** (applies Mirror and other modifiers) |
| Data > Mesh | UVs, Normals | On (the defaults) |
| Data > Material | Materials | Export; Images: Automatic (the defaults) |
| Animation | Animation | Off, unless the model has animations you want (see [section 7](#7-animating-parts) for the settings) |

4. Name the file after the character (e.g. `chaser.glb`). Export it straight
   into the Godot project folder (see [section 8](#8-where-to-keep-files)).
   Use the **same name every time** you re-export, so Godot updates the model
   in the game automatically.

**Shortcut for re-exporting:** Blender can remember these settings.
1. Put the model in its own collection.
2. Open **Collection Properties > Exporters > Add > glTF 2.0** and fill in the
   settings and file path once.
3. Afterwards, **File > Export All Collections** re-exports in one click.

---

## 6. Put it in the game (Godot)

### Import

Switch to the Godot editor. It notices the new `.glb` and imports it.

**The texture should stay inside the model, uncompressed.** This is the
**GLTF > Embedded Image Handling** import setting, and it should be
**Embed as Uncompressed**.
- The texture then stays inside the `.glb` with its exact colours, and no
  extra PNG file is made.
- Godot's own default, **Extract Textures**, instead writes the texture next to
  the model as `<glb name>_<image name>.png` and compresses it, which ruins
  palette colours.

**Make Embed as Uncompressed the default (once per project).** Afterwards,
every new `.glb` uses it automatically.

1. In the FileSystem dock, select a model that already uses it, e.g.
   `gfx/models/buzzsaw.glb`. Check in the **Import** dock that
   **GLTF > Embedded Image Handling** says **Embed as Uncompressed**.
2. At the top of the Import dock, click **Preset** and choose
   **Set as Default for 'Scene'**.

Godot saves this in `project.godot` under `[importer_defaults]`; commit that
file. The default applies to models imported **after** it is set. Models
already in the project keep their own settings.

Another way to set it: **Project > Project Settings > Import Defaults** tab.
Choose the **Scene** importer and set **GLTF > Embedded Image Handling** there.

**Check each new model:** select the `.glb` and look at
**GLTF > Embedded Image Handling** in the Import dock. If it says anything other
than Embed as Uncompressed (e.g. it was imported before the default was set):
1. Set it to **Embed as Uncompressed** and click **Reimport**.
2. Delete the extracted `<glb name>_<image name>.png` and its `.import` file;
   nothing uses them any more.

If a model is left on Extract Textures, don't rename or delete its extracted
PNG: the model needs that exact file and shows no texture without it.

#### Palette textures vs painted textures

Embed as Uncompressed suits **palette textures** (section 4A), which are tiny
and have one flat colour per face. It is a poor choice for **detailed painted
textures** (section 4B):

- **Video memory.** Uncompressed textures take about 4 bytes per pixel. Godot's
  VRAM Compressed takes 0.5 to 1 byte per pixel, and stays compressed on the
  graphics card. Low spec machines have little video memory.

  | Texture | Uncompressed | VRAM Compressed |
  |---|---|---|
  | 16 x 8 palette | about 0.5 KB | about 0.1 KB |
  | 1024 x 1024 painted | about 4 MB (5.3 MB with mipmaps) | about 0.5 to 1 MB |
  | 2048 x 2048 painted | about 16 MB (21 MB with mipmaps) | about 2 to 4 MB |

- **No mipmaps.** Mipmaps are smaller copies the graphics card uses when a
  texture is drawn small, and embedded textures don't get them. With a top-down
  camera a 2 m enemy is only about 50 pixels tall, so a detailed texture without
  mipmaps flickers and sparkles as it moves. Palettes are unaffected because
  each face is one flat colour.
- **Less control.** An embedded texture has no import settings of its own, and
  every model carries its own copy.

VRAM compression works on 4 x 4 blocks of pixels and keeps only a couple of
colours per block. That is fine for painted textures, where neighbouring pixels
are similar, and is why it ruins palettes, where every pixel is a different
colour.

**For a model with a detailed painted texture:**
1. Select the `.glb`. In the Import dock, set **Embedded Image Handling** to
   **Extract Textures** for that model only, and click **Reimport**. The project
   default only sets the starting value, so changing one model is fine.
2. Select the extracted PNG and leave **Compress > Mode** on **VRAM Compressed**.
   Turn on **High Quality** for better colour (1 byte per pixel).
3. Keep **Mipmaps > Generate** on.
4. Commit the extracted PNG and its `.import` file, and don't rename them.

**Embed as Basis Universal** (the other embed option) also compresses, so it has
the same problem with palettes. It is not worth using here.

### Replace an enemy's placeholder

The example uses the Chaser; the Tank and Angry Greg work the same way.

1. Open `scn/game/chaser.tscn`.
2. Expand the **Model** node and delete `PlaceholderBody` and
   `PlaceholderNose`. For the Tank it is `PlaceholderBarrel`; for Greg, also
   `PlaceholderBrowLeft` and `PlaceholderBrowRight`.
3. Drag `chaser.glb` from the FileSystem dock onto the **Model** node. Its
   Position and Rotation should be 0, 0, 0.
4. Check the facing: with the new model selected, the blue (Z) arrow of the
   move gizmo should point out of the model's front. The code turns **Model**
   so that +Z points where the enemy is heading.
5. If the model is a different size from the placeholder, change the radius of
   both spheres:
   - **CollisionShape3D** is the body.
   - **Hurtbox > CollisionShape3D** should be 0.1 m bigger.
6. Save the scene and run the game (**F5**).

The enemy fade-in works with the imported model automatically.

### Replace the player's placeholder

Do the same in `scn/game/player.tscn` under **Model**: delete
`PlaceholderBody` and `PlaceholderNose`, then drag in the `.glb`. The player's
blink while invulnerable also works automatically.

**Then fix the dash animation.** It squashes and stretches `PlaceholderBody`,
which no longer exists. If you skip this, Godot warns about a missing node and
the dash has no effect.
1. Select the **AnimationPlayer** and open the **Animation** panel at the
   bottom.
2. Choose the **dash** animation. Click the track's name
   (`Model/PlaceholderBody:scale`) and change it to point at your model,
   e.g. `Model/player:scale`. Use the name your model has in the scene tree.
3. Do the same for the **RESET** animation.
4. Keep both animation names. The code plays `dash` during a dash and `RESET`
   when it ends.

### Changing the model later

1. Edit the `.blend`.
2. Export again to the same `.glb` path.
3. Switch back to Godot. It reimports, and every scene that uses the model
   updates.

### Editing the material in Godot (optional)

Imported materials are read-only in Godot. To tweak one, for example to add
emission, double-click the `.glb` to open **Advanced Import Settings**.
1. Select the material and turn on **Use External**.
2. Choose a path for a `.tres` file and click **Reimport**.
3. That `.tres` can now be edited, and re-exports from Blender keep using it.
   Stick to StandardMaterial3D settings. A ShaderMaterial stops the enemy
   fade-in working (the enemy pops in instead).

---

## 7. Animating parts

This section shows how to make one part of a model move on its own, for
example a turret spinning on top of a body. The animation is made in Blender
and comes into Godot with the model.

### Prepare the parts in Blender

1. **Keep the moving part as a separate object.** Join the parts that don't
   move with **Ctrl+J**, but leave the moving part out. Godot imports each
   object as its own node.
2. **Put the part's origin on the pivot.** An object rotates around its origin
   (the orange dot).
   - In Edit Mode, select the vertices at the pivot (e.g. the base of the
     turret).
   - Press **Shift+S > Cursor to Selected**.
   - Back in Object Mode, use **Object > Set Origin > Origin to 3D Cursor**.
3. **Parent it to the body.** Click the part, then Shift+click the body (the
   body must be selected last). Press **Ctrl+P > Object**. In Godot the part
   becomes a child of the body node.
4. Apply only **Ctrl+A > Rotation & Scale** on the moving part, not All
   Transforms (see section 3).

### Animate it

1. Switch to the **Animation** workspace.
2. Go to frame **1** and select the part. Hover over **Rotation** in the side
   panel (**N**) and press **I** to insert a keyframe.
3. Go to frame **49**. At 24 fps that is 2 seconds later; the frame rate is in
   **Output Properties > Frame Rate**. Set **Rotation Z** to `360` and press
   **I** again.
4. **Make the speed constant.** Blender eases in and out between keyframes by
   default, so a spin would creep, speed up, then slow down. In the timeline at
   the bottom, press **A** to select all keys, then **T > Linear**.
5. **Name the animation.** In the **Dope Sheet**, switch the mode to
   **Action Editor** and rename the action, e.g. `spin-loop`.
   - Godot sees the `-loop` ending, sets the animation to loop and removes the
     ending, so it arrives as `spin`.
   - Leave `-loop` off for animations that should play once.
6. **Looping motions that aren't full turns** (flapping, bobbing): make the
   first and last keyframes the same pose, so the loop has no jump.

Blender's Z (up) becomes Godot's Y (up), so a Z spin in Blender is a Y spin in
the game.

### Export settings for animation

Use the settings from section 5, plus these in the **Animation** section:

| Setting | Value |
|---|---|
| Animation | **On** |
| Always Sample Animations | On (the default). It is needed for a full 360° turn to come through |
| Set All glTF Animation Starting at 0 | **On**. Without it, the animation has an extra frame of stillness at the start, which shows as a hitch on every loop |

### Play it in Godot

The `.glb` arrives with its own **AnimationPlayer**, next to the model's
nodes. It doesn't play anything until told to. Choose one of the two ways
below.

**Without code (autoplay):**

1. In the enemy or player scene, right-click the model's instance under
   **Model** and choose **Editable Children**. The nodes inside the `.glb`
   appear, greyed out.
2. Select its **AnimationPlayer**. In the Animation panel, choose the
   animation (e.g. `spin`) and click **Autoplay on Load**.
3. In the Inspector, set **Callback Mode > Process** to **Physics**.
   Everything in this game moves in the physics step with physics
   interpolation, and this keeps the animation in step with it.

These settings are saved in your scene. Re-exporting from Blender keeps them,
as long as the animation name stays the same.

**From code:** to start the animation only once an enemy has finished fading
in, add a line to that enemy's `_on_activated()`:

```gdscript
$Model/chaser/AnimationPlayer.play("spin")   # the path depends on your node names
```

### Other ways to move a part

- **Rotation that reacts to gameplay**, such as a turret aiming at the player,
  belongs in code rather than an animation. In the enemy's
  `_active_physics_process(delta)`, turn that part's node with `look_at()` or
  by changing its `rotation.y`. Turn on **Editable Children** (above) to see
  the part's node path. Blender animations are best for movement that always
  plays the same way: spinning, flapping, wobbling.
- **Animating in Godot:** with Editable Children on, the scene's own
  AnimationPlayer can key the part's rotation, like the player's `dash`
  animation does. That is handy for small game-feel touches you want to tweak
  in Godot alongside the code.

### Works with the existing game code

- The enemy fade-in includes every mesh under **Model**, however deeply nested.
- Animations stop while the game is paused.
- The player's invulnerability blink hides the whole **Model**, so animated
  parts blink too.

---

## 8. Where to keep files

| File | Where | Notes |
|---|---|---|
| `.glb` (texture stored inside it) and its `.import` file | `src/gfx/models/`, e.g. `src/gfx/models/example.glb` | Inside the Godot project, so the game can use them |
| `.blend` and source PNGs | Outside of the project | Godot tries to import `.blend` files it finds in the project, which needs Blender on every machine that opens it. Exporting `.glb` avoids that |

When a human-made model replaces a placeholder:
- Remove the placeholder's entry from `docs/asset_tracking.txt`.
- Add the artist's credit to `docs/credits.txt`.

---

## 9. Quick checklist

- [ ] Fits the hitbox: 2 x 2 m, or 4 x 4 m for a boss. Centre at the origin, bottom at Z = -1
- [ ] Faces -Y in Blender (looks at you in Front view)
- [ ] Reads well from Top view, with strong colours
- [ ] Under the triangle budget (Statistics overlay)
- [ ] One object (plus any animated parts), one material, small texture, Image Texture set to Closest
- [ ] Ctrl+A > All Transforms applied (Rotation & Scale only on animated parts)
- [ ] Animated parts: origin on the pivot, parented to the body, keys set to Linear for steady motion, `-loop` on looping action names
- [ ] Animation exported with Animation and Set All glTF Animation Starting at 0 on; in Godot, autoplay set (or played from code) with Callback Mode Process on Physics
- [ ] Exported as `.glb` with Selected Objects, +Y Up and Apply Modifiers
- [ ] In Godot: palette models use **Embed as Uncompressed** with no extracted PNG next to the `.glb`. Painted-texture models use **Extract Textures**, VRAM Compressed and mipmaps
- [ ] In Godot: placeholder removed, model under **Model**, blue Z arrow points forward
- [ ] Hitbox radii updated if the size changed
- [ ] Player only: dash and RESET tracks point at the new model
- [ ] `docs/asset_tracking.txt` and `docs/credits.txt` updated
